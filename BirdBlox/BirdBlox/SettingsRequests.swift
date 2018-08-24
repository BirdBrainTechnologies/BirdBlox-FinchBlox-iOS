//
//  SettingsRequests.swift
//  BirdBlox
//
//  Created by birdbrain on 4/27/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
//import Swifter

class SettingsManager: NSObject {
    
    func loadRequests(server: BBTBackendServer){
		//settings/getSetting?key=foo
        server["/settings/get"] = self.getSettingRequest
		
		//settings/setSetting?key=foo&value=bar
        server["/settings/set"] = self.setSettingRequest
    }
	
    func getSettingRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		if let key = (queries["key"]) {
			let value = DataModel.shared.getSetting(key)
			if let nullCheckedValue = value {
				return .ok(.text(nullCheckedValue))
			} else {
				return .notFound
			}
		}
		
		return .badRequest(.text("Malformed request"))
    }
	
    func setSettingRequest(request: HttpRequest) -> HttpResponse {
		let captured = BBTSequentialQueryArrayToDict(request.queryParams)
		
        if let key = (captured["key"]),
			let value = (captured["value"]) {
			DataModel.shared.addSetting(key, value: value)
			return .ok(.text("Setting saved"))
		}
		
		return .badRequest(.text("Malformed request"))
    }
}
