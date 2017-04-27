//
//  SettingsRequests.swift
//  BirdBlox
//
//  Created by birdbrain on 4/27/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import Swifter

class SettingsRequests: NSObject {
    
    let audio_manager: AudioManager
    
    override init(){
        audio_manager = AudioManager()
        super.init()
    }
    
    func loadRequests(server: inout HttpServer){
        server["/settings/get/:key"] = getSettingRequest(request:)
        server["/settings/set/:key/:value"] = setSettingRequest(request:)

    }
    func getSettingRequest(request: HttpRequest) -> HttpResponse {
        let key = (request.params[":key"]?.removingPercentEncoding)!
        let value = getSetting(key)
        if let nullCheckedValue = value {
            return .ok(.text(nullCheckedValue))
        } else {
            return .ok(.text("Default"))
        }
    }
    
    func setSettingRequest(request: HttpRequest) -> HttpResponse {
        let captured = request.params
        let key = (captured[":key"]?.removingPercentEncoding)!
        let value = (captured[":value"]?.removingPercentEncoding)!
        addSetting(key, value: value)
        return .ok(.text("Setting saved"))
    }

}
