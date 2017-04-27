//
//  MainServer.swift
//  BirdBlox
//
//  Created by birdbrain on 3/21/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import Swifter

class MainServer {
    let port = 22179
    var server: HttpServer
    let hummingbird_requests: HummingbirdRequests
    let flutter_requests: FlutterRequests
    
    init(){
        hummingbird_requests = HummingbirdRequests()
        flutter_requests = FlutterRequests()
        server = HttpServer()
        
        server["/DragAndDrop/:path1"] = handleFrontEndRequest
        server["/DragAndDrop/:path1/:path2/:path3"] = handleFrontEndRequest
        server["/server/ping"] = {r in return .ok(.text("pong"))}
        hummingbird_requests.loadRequests(server: &server)
        flutter_requests.loadRequests(server: &server)
        
    }
    
    func start() {
        do {
            try server.start(22179, forceIPv4: true, priority: DispatchQoS.default.qosClass)
        } catch {
            return
        }
        
        print (server.routes)
    }
    
}
