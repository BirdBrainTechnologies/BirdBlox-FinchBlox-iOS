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

class BBTBackendServer {
	let port = 22179
	let swifterServer: HttpServer
	
	var pathDict: Dictionary<String, ((HttpRequest) -> HttpResponse)>
	
	init() {
		pathDict = Dictionary()
		
		swifterServer = HttpServer()
		swifterServer.notFoundHandler = self.notFoundHandler
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
	
	//Ideally I would like to override the dispatch method of HttpServer, but since I can't inherit
	//I have to settle for doing this to jump in front of every handler –J
	subscript(path: String) -> ((HttpRequest) -> HttpResponse)? {
		set(handler) {
			func guardedHandler(request: HttpRequest) -> HttpResponse {
				let address = request.address ?? "unknown"
				
				//TODO Decide if necessary to remove totalStatus commands in
				if !request.path.contains("totalStatus") { //So output is actually readable
					NSLog("HTTP Request \(request.path) from address \(address).")
				}
				
				
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
			}
			swifterServer[path] = (handler != nil ? guardedHandler : handler)
		}
		get{ return swifterServer[path] }
	}
	
	func start() {
		do {
			try swifterServer.start(in_port_t(port), forceIPv4: true,
			                        priority: DispatchQoS.default.qosClass)
			NSLog("Server started")
		} catch {
			return
		}
	}
	
	func stop() {
		NSLog("Server stopping")
		self.swifterServer.stop()
	}
}
