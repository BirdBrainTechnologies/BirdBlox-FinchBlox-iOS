//
//  BBTBackendServer.swift
//  BirdBlox
//
//  Created by Jeremy Huang on 2017-05-30.
//  Copyright © 2017年 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
//import Swifter
import WebKit

class BBTBackendServer: NSObject, WKScriptMessageHandler {
	var pathDict: Dictionary<String, ((HttpRequest) -> HttpResponse)>
	
	let backgroundQueue = DispatchQueue(label: "background", qos: .background,
	                                    attributes: .concurrent)
	let regularQueue = DispatchQueue(label: "birdblox", qos: .userInitiated,
	                                 attributes: .concurrent)
//	let regularQueue = DispatchQueue.global(qos: .userInteractive)
//	let backgroundQueue = DispatchQueue.global(qos: .background)
	
	let router = HttpRouter()
	
	private var clearingRegularQueue = false
	let queueClearingLock = NSCondition()
	
	let backgroundQueueBlockCountLock = NSCondition()
	var backgroundQueueBlockCount = 0
	let maxBackgroundQueueBlockCount = 30
	
	override init() {
		pathDict = Dictionary()
	}
	
	private func notFoundHandler(request: HttpRequest) -> HttpResponse {
		if request.address == nil || request.address != BBTLocalHostIP {
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
			if let handler = handler {
                func guardedHandler(request: HttpRequest) -> HttpResponse {
                    
                    NSLog("Faux HTTP Request \(request.path) from address \(request.address ?? "unknown").")
                    
                    if request.address == nil || request.address != BBTLocalHostIP{
                        #if DEBUG
                        NSLog("Permitting external request in DEBUG mode.")
                        #else
                        NSLog("Forbidding external request.")
                        return .forbidden
                        #endif
                    }
                    
                    //Only use the guarded handler if there is a handler to guard
                    return handler(request)
                }
                
				self.pathDict[path] = guardedHandler
				self.router.register(nil, path: path, handler: guardedHandler)
			} else {
				self.pathDict.removeValue(forKey: path)
				self.router.register(nil, path: path, handler: nil)
			}
		}
		get{ return pathDict[path] }
	}
	
	public func handleNativeCall(responseID: String, requestStr: String, body: String?,
	                             background: String = "true") {
		let nativeCallBlock = {
			let request = HttpRequest()
			request.address = BBTLocalHostIP
			request.path = requestStr
			request.queryParams = self.extractQueryParams(request.path)
			if let bodyBytes = body?.utf8 {
				request.body = [UInt8](bodyBytes)
			}
			
			let (params, handler) =
			self.router.route(nil, path: request.path) ?? ([:], self.notFoundHandler)
			
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
		
		if background == "false" {
			self.regularQueue.async(execute: nativeCallBlock)
		}
		else if self.backgroundQueueBlockCount < self.maxBackgroundQueueBlockCount {
			self.backgroundQueueBlockCountLock.lock()
			self.backgroundQueueBlockCount += 1
			self.backgroundQueueBlockCountLock.unlock()
			
			let cancellableBlock = {
				if !self.clearingRegularQueue {
					nativeCallBlock()
				}
				self.backgroundQueueBlockCountLock.lock()
				self.backgroundQueueBlockCount -= 1
				self.backgroundQueueBlockCountLock.unlock()
			}
			self.backgroundQueue.async(execute: cancellableBlock)
		} else {
			NSLog("Dropped request because max background queue size exceeded. \(requestStr)")
		}
	}
	
	//Only one instance of this function can be run at a time
	//Swift does not have a native way to do a mutex lock yet.
	//Not much point anymore because queue is unlikely to have backlog.
	public func clearBackgroundQueue(completion: (() -> Void)? = nil) {
		self.queueClearingLock.lock()
		
		self.clearingRegularQueue = true
		self.backgroundQueue.async {
			self.clearingRegularQueue = false
		}
		
		self.queueClearingLock.unlock()
		
		if let comp = completion {
			comp()
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
//		NSLog("Sever get webkit message: \(message.name)")
//		print(message.body)
		
		guard message.name == "serverSubstitute",
			let obj = message.body as? NSDictionary,
			let requestStr = obj["request"] as? String,
			let body = obj["body"] as? String,
			let id = obj["id"] as? String,
			let background = obj["inBackground"] as? String else {
			print("Unable to respond")
			return
		}
		
		NSLog("bg \(background) faux req \(requestStr)")
        
		self.handleNativeCall(responseID: id, requestStr: requestStr, body: body,
		                      background: background)
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
		guard let questionMark = url.index(of: "?") else {
			return []
		}
		let queryStart = url.index(after: questionMark)
		guard url.endIndex > queryStart else {
			return []
		}
        let query = String(url[queryStart..<url.endIndex])
        
		return query.components(separatedBy: "&")
			.reduce([(String, String)]()) { (c, s) -> [(String, String)] in
				guard let nameEndIndex = s.index(of: "="),
                    let name = String(s[s.startIndex..<nameEndIndex]).removingPercentEncoding else {
					return c
				}
				let valueStartIndex = s.index(nameEndIndex, offsetBy: 1)
				guard valueStartIndex < s.endIndex,
                    let value = String(s[valueStartIndex..<s.endIndex]).removingPercentEncoding else {
					return c + [(name, "")]
				}
				
				return c + [(name, value)]
		}
	}
}
