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
        server["/settings/get"] = getSettingRequest(request:)
		
		//settings/setSetting?key=foo&value=bar
        server["/settings/set"] = setSettingRequest(request:)

    }
    func getSettingRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		if let key = (queries["key"]?.removingPercentEncoding) {
			let value = getSetting(key)
			if let nullCheckedValue = value {
				return .ok(.text(nullCheckedValue))
			} else {
				return .ok(.text("Default"))
			}
		}
		
		return .badRequest(.text("Malformed request"))
    }
	
    func setSettingRequest(request: HttpRequest) -> HttpResponse {
		let captured = BBTSequentialQueryArrayToDict(request.queryParams)
		
        if let key = (captured["key"]?.removingPercentEncoding),
			let value = (captured["value"]?.removingPercentEncoding) {
			addSetting(key, value: value)
			return .ok(.text("Setting saved"))
		}
		
		return .badRequest(.text("Malformed request"))
    }

}
