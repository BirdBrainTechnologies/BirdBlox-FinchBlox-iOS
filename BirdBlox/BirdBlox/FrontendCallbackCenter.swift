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
	
	var webView: WKWebView? = nil
	
	
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
	
		let function = "CallbackManager.dialog.promptResponded"
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
	
	
	func choiceResponded() -> Bool {
		guard let wv = self.webView else {
			return false
		}
		
		let function = "CallbackManager.dialog.alertResponded"
		let parameters = "()"
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
	
	public func robotUpdateStatus(id: String, connected: Bool) -> Bool {
		guard let wv = self.webView else {
			return false
		}
		
		let safeResponse = " '\(FrontendCallbackCenter.safeString(from: id))' "
		
		let function = "CallbackManager.dialog.updateStatus"
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
	
}