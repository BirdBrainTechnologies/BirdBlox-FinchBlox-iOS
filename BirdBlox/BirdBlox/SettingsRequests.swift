//
//  SettingsRequests.swift
//  BirdBlox
//
//  Created by birdbrain on 4/27/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import Swifter

class SettingsManager: NSObject {
    
    func loadRequests(server: BBTBackendServer){
		//settings/getSetting?key=foo
        server["/settings/get/:key"] = getSettingRequest(request:)
		
		//settings/setSetting?key=foo&value=bar
        server["/settings/set/:key/:value"] = setSettingRequest(request:)

    }
    func getSettingRequest(request: HttpRequest) -> HttpResponse {
//		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
//		let key = queries["key"]
		
        let key = (request.params[":key"]?.removingPercentEncoding)!
		
        let value = getSetting(key)
        if let nullCheckedValue = value {
            return .ok(.text(nullCheckedValue))
        } else {
            return .ok(.text("Default"))
        }
    }
    
    func setSettingRequest(request: HttpRequest) -> HttpResponse {
//        let captured = request.params
		
		let captured = BBTSequentialQueryArrayToDict(request.queryParams)
		
        let key = (captured[":key"]?.removingPercentEncoding)!
        let value = (captured[":value"]?.removingPercentEncoding)!
		
        addSetting(key, value: value)
        return .ok(.text("Setting saved"))
    }

}
