//
//  BBTBackendServer.swift
//  BirdBlox
//
//  Created by Jeremy Huang on 2017-05-30.
//  Copyright © 2017年 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import Swifter
import WebKit

class BBTBackendServer: NSObject, WKScriptMessageHandler {
	var pathDict: Dictionary<String, ((HttpRequest) -> HttpResponse)>
	
	let uiQueue = DispatchQueue(label: "Blox UI Work", qos: .userInteractive,
	                            attributes: .concurrent)
	let regularQueue = DispatchQueue(label: "Blox Work", qos: .default,
	                                 attributes: .concurrent)
//	let regularQueue = DispatchQueue.global(qos: .background)
	
	let router = HttpRouter()
	
	override init() {
		pathDict = Dictionary()
	}
	
	private func notFoundHandler(request: HttpRequest) -> HttpResponse {
		if request.address == nil || request.address != BBTLocalHostIP{
			#if DEBUG
			#else
				return .forbidden
			#endif
		}

		if let handler = pathDict[request.path] {
			return handler(request)
		}

		let address = request.address ?? "unknown"
		NSLog("Unable to find handler for Request \(request.path) from address \(address).")

		return .notFound
	}
	
	
	subscript(path: String) -> ((HttpRequest) -> HttpResponse)? {
		set(handler) {
			func guardedHandler(request: HttpRequest) -> HttpResponse {
				let address = request.address ?? "unknown"
				
				NSLog("Faux HTTP Request \(request.path) from address \(address).")
				
				
				if request.address == nil || request.address != BBTLocalHostIP{
					#if DEBUG
						NSLog("Permitting external request in DEBUG mode.")
					#else
						NSLog("Forbidding external request.")
						return .forbidden
					#endif
				}
				
				//Only use the guarded handler if there is a handler to guard
				return handler!(request)
			}
			
			if handler != nil {
				self.pathDict[path] = guardedHandler
				self.router.register(nil, path: path, handler: guardedHandler)
			} else {
				self.pathDict.removeValue(forKey: path)
				self.router.register(nil, path: path, handler: nil)
			}
		}
		get{ return pathDict[path] }
	}
	
	public func handleNativeCall(responseID: String, requestStr: String, body: String?) {
		self.regularQueue.async {
			let request = HttpRequest()
			request.address = BBTLocalHostIP
			request.path = requestStr
			request.queryParams = self.extractQueryParams(request.path)
			if let bodyBytes = body?.utf8 {
				request.body = [UInt8](bodyBytes)
			}
			
			let (params, handler) = self.router.route(nil, path: request.path) ?? ([:], self.notFoundHandler)
			request.params = params
			
			let resp = handler(request)
			
			let code = resp.statusCode()
			var bodyStr = ""
			
			//Extract the body and put it in bodyStr if possible
			let len = resp.content().length
			if len > 0 {
				let bytesAccessor = BytesAccessor(length: len)
				let bodyClosure = resp.content().write ?? { try $0.write([]) }
				
				do {
					try bodyClosure(bytesAccessor)
					if let s = String(data: bytesAccessor.data, encoding: .utf8) {
						bodyStr = s
					}
				} catch {
					NSLog("Unable to obtain response data.")
				}
			}
			
			let _ = FrontendCallbackCenter.shared
			.sendFauxHTTPResponse(id: responseID, status: code, obody: bodyStr)
		}
	}
	
	//MARK: WKScriptMessageHandler
	
	/*! @abstract Invoked when a script message is received from a webpage.
	@param userContentController The user content controller invoking the
	delegate method.
	@param message The script message received.
	*/
	@available(iOS 8.0, *)
	func userContentController(_ userContentController: WKUserContentController,
	                           didReceive message: WKScriptMessage) {
		NSLog("Sever get webkit message: \(message.name)")
//		print(message.body)
		
		guard message.name == "serverSubstitute",
			let obj = message.body as? NSDictionary,
			let requestStr = obj["request"] as? String,
			let body = obj["body"] as? String,
			let id = obj["id"] as? String else {
			print("Unable to repsond")
			return
		}
		
		self.handleNativeCall(responseID: id, requestStr: requestStr, body: body)
	}
	
	
	//TODO: Delete
	func start() {
		NSLog("faux Server faux started, state \(9)")
	}
	
	func stop() {
		NSLog("faux Server faux stopping")
	}
	
	
	//MARK: For Native Call compatibility with HttpServer
	
	//Used to extract Http response bodies
	class BytesAccessor: HttpResponseBodyWriter {
		var data: Data
		let len: Int
		
		init(length: Int) {
			self.data = Data(capacity: length)
			self.len = length
		}
		
		func write(_ data: [UInt8]) throws {
			self.data.append(contentsOf: data)
		}
		
		func write(_ file: String.File) throws {
			var bytes = Array<UInt8>(repeating: 0, count: self.len)
			let _  = try file.read(&bytes)
			try self.write(bytes)
		}
		
		func write(_ data: Data) throws {
			//			data.copyBytes(to: &self.bytes, count: bytes.count)
			self.data = data
		}
		
		func write(_ data: NSData) throws {
			try self.write(data as Data)
		}
		
		func write(_ data: ArraySlice<UInt8>) throws -> () {
			let bytes = Array(data)
			try self.write(bytes)
		}
	}
	
	//Query parameter extraction function from Swifter
	//Unfortunately we can't just call it because we need to make an HttpRequest from 
	//the native call and not just a socket. (This function is private.)
	private func extractQueryParams(_ url: String) -> [(String, String)] {
		guard let questionMark = url.characters.index(of: "?") else {
			return []
		}
		let queryStart = url.characters.index(after: questionMark)
		guard url.endIndex > queryStart else {
			return []
		}
		let query = String(url.characters[queryStart..<url.endIndex])
		return query.components(separatedBy: "&")
			.reduce([(String, String)]()) { (c, s) -> [(String, String)] in
				guard let nameEndIndex = s.characters.index(of: "=") else {
					return c
				}
				guard let name = String(s.characters[s.startIndex..<nameEndIndex]).removingPercentEncoding else {
					return c
				}
				let valueStartIndex = s.index(nameEndIndex, offsetBy: 1)
				guard valueStartIndex < s.endIndex else {
					return c + [(name, "")]
				}
				guard let value = String(s.characters[valueStartIndex..<s.endIndex]).removingPercentEncoding else {
					return c + [(name, "")]
				}
				return c + [(name, value)]
		}
	}
}

//class BBTBackendServer {
//	let port = 22179
//	let swifterServer: HttpServer
//
//	var pathDict: Dictionary<String, ((HttpRequest) -> HttpResponse)>
//
//	let uiQueue = DispatchQueue(label: "Blox UI Work", qos: .userInteractive,
//	                            attributes: .concurrent)
//	let regularQueue = DispatchQueue(label: "Blox Work", qos: .default,
//	                                 attributes: .concurrent)
//	
//	init() {
//		pathDict = Dictionary()
//		
//		swifterServer = HttpServer()
//		swifterServer.notFoundHandler = self.notFoundHandler
//	}
//	
//	private func notFoundHandler(request: HttpRequest) -> HttpResponse {
//		if request.address == nil || request.address != BBTLocalHostIP{
//			#if DEBUG
//			#else
//				return .forbidden
//			#endif
//		}
//		
//		if let handler = pathDict[request.path] {
//			return handler(request)
//		}
//		
//		let address = request.address ?? "unknown"
//		NSLog("Unable to find handler for Request \(request.path) from address \(address).")
//		
//		return .notFound
//	}
//	
//	//Ideally I would like to override the dispatch method of HttpServer, but since I can't inherit
//	//I have to settle for doing this to jump in front of every handler –J
//	subscript(path: String) -> ((HttpRequest) -> HttpResponse)? {
//		set(handler) {
//			func guardedHandler(request: HttpRequest) -> HttpResponse {
//				let address = request.address ?? "unknown"
//				
//				NSLog("HTTP Request \(request.path) from address \(address).")
//				
//				
//				if request.address == nil || request.address != BBTLocalHostIP{
//					#if DEBUG
//						NSLog("Permitting external request in DEBUG mode.")
//					#else
//						NSLog("Forbidding external request.")
//						return .forbidden
//					#endif
//				}
//				
//				//Only use the guarded handler if there is a handler to guard
//				return handler!(request)
//			}
//			
//			if handler != nil {
//				self.pathDict[path] = guardedHandler
//			}
//			swifterServer[path] = (handler != nil ? guardedHandler : handler)
//		}
//		get{ return swifterServer[path] }
//	}
//	
//	func start() {
//		do {
//			try swifterServer.start(in_port_t(port), forceIPv4: true,
//			                        priority: DispatchQoS.default.qosClass)
//			NSLog("Server started, state \(swifterServer.state)")
//		} catch {
//			return
//		}
//	}
//	
//	func stop() {
//		NSLog("Server stopping")
//		self.swifterServer.stop()
//	}
//}
