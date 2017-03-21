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
    let server: HttpServer
    
    init(){
        server = HttpServer()
        server.GET["/DragAndDrop/:path1"] = handleFrontEndRequest
        server.GET["/DragAndDrop/:path1/:path2/:path3"] = handleFrontEndRequest
        
        server.GET["/server/ping"] = {r in return .ok(.text("pong"))}

    }
    func start() {
        do {
            try server.start(22179)
        } catch {
            return
        }
    }
    
}
