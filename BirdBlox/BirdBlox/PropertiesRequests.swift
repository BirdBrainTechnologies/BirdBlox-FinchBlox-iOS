//
//  PropertiesRequests.swift
//  BirdBlox
//
//  Created by Jeremy Huang on 2017-05-22.
//  Copyright © 2017年 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import Swifter

struct PropertiesManager {

	func loadRequests(server: BBTBackendServer){
		server["/properties/dims"] = self.getPhysicalDims
		server["/properties/os"] = self.getVersion
	}
	
	func mmFromPoints(p:CGFloat) -> CGFloat {
		let mmPerPoint = BBTThisIDevice.milimetersPerPointFor(deviceModel:
		BBTThisIDevice.platformModelString())
		
		return p * mmPerPoint
	}
	
	func getPhysicalDims(request: HttpRequest) -> HttpResponse {
		let heightInPoints = UIScreen.main.bounds.height
		let height = mmFromPoints(p: heightInPoints)
		
		let widthInPoints = UIScreen.main.bounds.width
		let width = mmFromPoints(p: widthInPoints)
		
//		print(request.params)
//		print(request.queryParams)
//		print(request.method)
//		print(request.path)
		
		return .ok(.text("\(width),\(height)"))
	}
	
	func getVersion(request: HttpRequest) -> HttpResponse {
		let os = "iOS"
		let version = ProcessInfo().operatingSystemVersion
		
		return .ok(.text("\(os) " +
		               "(\(version.majorVersion).\(version.minorVersion).\(version.patchVersion))"))
	}
	
}
