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
	
    public let hummingbird_requests: HummingbirdRequests
    public let flutter_requests: FlutterRequests
    let data_requests: DataRequests
    let host_device_requests: HostDeviceRequests
    let sound_requests: SoundRequests
    let settings_requests: SettingsRequests
	let properties_requests: PropertiesRequests
	
    let view_controller: UIViewController
    
    init(view_controller: ViewController){
        self.view_controller = view_controller
        hummingbird_requests = HummingbirdRequests()
        flutter_requests = FlutterRequests()
        data_requests = DataRequests(view_controller: view_controller)
        host_device_requests = HostDeviceRequests(view_controller: view_controller)
        sound_requests = SoundRequests()
        settings_requests = SettingsRequests()
		properties_requests = PropertiesRequests()
        server = HttpServer()
        
        server["/DragAndDrop/:path1"] = handleFrontEndRequest
        server["/DragAndDrop/:path1/:path2/"] = handleFrontEndRequest
        server["/DragAndDrop/:path1/:path2/:path3"] = handleFrontEndRequest
        server["/server/ping"] = {r in return .ok(.text("pong"))}
        hummingbird_requests.loadRequests(server: &server)
        flutter_requests.loadRequests(server: &server)
        data_requests.loadRequests(server: &server)
        host_device_requests.loadRequests(server: &server)
        sound_requests.loadRequests(server: &server)
        settings_requests.loadRequests(server: &server)
		properties_requests.loadRequests(server: &server)
    }
    
    func start() {
        do {
            try server.start(in_port_t(port), forceIPv4: true, priority: DispatchQoS.default.qosClass)
        } catch {
            return
        }
        
        print (server.routes)
    }
    
}
