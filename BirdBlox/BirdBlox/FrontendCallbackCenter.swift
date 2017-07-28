//
//  FrontendCallbackCenter.swift
//  BirdBlox
//
//  Created by Jeremy Huang on 2017-06-20.
//  Copyright © 2017年 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import WebKit


class FrontendCallbackCenter {
	private static let singleton: FrontendCallbackCenter = FrontendCallbackCenter()
	
	public static var shared: FrontendCallbackCenter {
		return singleton
	}
	
	public static func safeString(from: String) -> String {
		return from.addingPercentEncoding(withAllowedCharacters: CharacterSet())!
	}
	
	public static func jsonString(from: Any) -> String? {
		do {
			let data = try JSONSerialization.data(withJSONObject: from, options: [.prettyPrinted])
			return String(data: data, encoding: .utf8)
		} catch {
			return nil
		}
	}
	
	var webView: WKWebView? = nil
	
	
	//MARK: Internal Method
	private func runJS(function: String, parameters: [String]) -> Bool {
		guard let wv = self.webView else {
			return false
		}
		
		let parametersStr = "(" + parameters.map({"'\($0)'"}).joined(separator: ", ") + ")"
		
		let js = function + parametersStr
		
		wv.evaluateJavaScript(js, completionHandler: { ret, error in
			if let error = error {
				NSLog("Error running '\(js)': \(error)")
				return
			}
			
			#if DEBUG
				print("Ran '\(js)', got \(String(describing: ret))")
			#endif
		})
		
		return true
	}
	
	
	//MARK: Dialog Responses
	public func dialogPromptResponded(cancelled: Bool, response: String?) -> Bool {
		guard let wv = self.webView else {
			return false
		}
		
		let safeResponse = " '\(FrontendCallbackCenter.safeString(from: response ?? ""))' "
		
		let function = "CallbackManager.dialog.promptResponded"
		let parameters = "(\(cancelled), \(safeResponse))"
		let js = function + parameters
		
		wv.evaluateJavaScript(js, completionHandler: { ret, error in
			if let error = error {
				print("Error running '\(js)': \(error)")
				return
			}
			
			print("Ran '\(js)', got \(String(describing: ret))")
		})
		
		return true
	}
	
	func choiceResponded(cancelled: Bool, firstSelected: Bool) -> Bool {
		guard let wv = self.webView else {
			return false
		}
	
		let function = "CallbackManager.dialog.choiceResponded"
		let parameters = "(\(cancelled), \(firstSelected))"
		let js = function + parameters
		
		wv.evaluateJavaScript(js, completionHandler: { ret, error in
			if let error = error {
				print("Error running '\(js)': \(error)")
				return
			}
			
			print("Ran '\(js)', got \(String(describing: ret))")
		})
		
		return true
	}
	
	//MARK: Robot Related
	public func robotUpdateStatus(id: String, connected: Bool) -> Bool {
		guard let wv = self.webView else {
			return false
		}
		
		let safeResponse = " '\(FrontendCallbackCenter.safeString(from: id))' "
		
		let function = "CallbackManager.robot.updateStatus"
		let parameters = "(\(safeResponse), \(connected))"
		let js = function + parameters
		
		wv.evaluateJavaScript(js, completionHandler: { ret, error in
			if let error = error {
				print("Error running '\(js)': \(error)")
				return
			}
			
			print("Ran '\(js)', got \(String(describing: ret))")
		})
		
		return true
	}
	
	public func robotFirmwareIncompatible(id: String, firmware: String) -> Bool {
		let safeID = FrontendCallbackCenter.safeString(from: id)
		let safeFirmware = FrontendCallbackCenter.safeString(from: firmware)
		
		let function = "CallbackManager.robot.disconnectIncompatible"
		let parameters = [safeID, safeFirmware, HummingbirdPeripheral.minimumFirmware]
		
		return self.runJS(function: function, parameters: parameters)
	}
	
	public func scanHasStopped(typeStr: String) -> Bool {
		let safeType = FrontendCallbackCenter.safeString(from: typeStr)
		
		let function = "CallbackManager.robot.stopDiscover"
		let parameters = [safeType]
		
		return self.runJS(function: function, parameters: parameters)
	}
	
	public func updateDiscoveredRobotList(typeStr: String, robotList: [[String: String]]) -> Bool {
		let safeType = FrontendCallbackCenter.safeString(from: typeStr)
		
		guard let jsonList = FrontendCallbackCenter.jsonString(from: robotList) else {
			return false
		}
		let safeList = FrontendCallbackCenter.safeString(from: jsonList)
		
		let function = "CallbackManager.robot.discovered"
		let parameters = [safeType, safeList]
		
		return self.runJS(function: function, parameters: parameters)
	}
	
	
	//MARK: Updating UI
	func documentSetName(name: String) -> Bool {
		let safeName = FrontendCallbackCenter.safeString(from: name)
		
		let function = "CallbackManager.data.setName"
		let parameters = [safeName]
		
		return self.runJS(function: function, parameters: parameters)
	}
	
	func markLoadingDocument() -> Bool {
		let function = "CallbackManager.data.markLoading"
		let parameters: [String] = []
		
		return self.runJS(function: function, parameters: parameters)
	}
	
	func recordingEnded() -> Bool {
		let function = "CallbackManager.sounds.recordingEnded"
		let parameters: Array<String> = []
		
		return self.runJS(function: function, parameters: parameters)
	}
	
	
	//MARK: misc., utility
	func echo(getRequestString: String) -> Bool {
		guard let wv = self.webView else {
			return false
		}
		
		let function = "CallbackManager.echo"
		let parameters = "('\(FrontendCallbackCenter.safeString(from: getRequestString))')"
		let js = function + parameters
		
		wv.evaluateJavaScript(js, completionHandler: { ret, error in
			if let error = error {
				print("Error running '\(js)': \(error)")
				return
			}
			
			print("Ran '\(js)', got \(String(describing: ret))")
		})
		
		return true
	}
}
