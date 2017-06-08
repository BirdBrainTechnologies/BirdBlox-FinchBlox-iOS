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
		print("Dims req")
		
		let window = UIApplication.shared.delegate?.window
		let heightInPoints = window??.bounds.height ?? UIScreen.main.bounds.height
		let height = mmFromPoints(p: heightInPoints)
		
		let widthInPoints = window??.bounds.width ?? UIScreen.main.bounds.width
		let width = mmFromPoints(p: widthInPoints)
		
		
		return .ok(.text("\(width),\(height)"))
	}
	
	func getVersion(request: HttpRequest) -> HttpResponse {
		let os = "iOS"
		let version = ProcessInfo().operatingSystemVersion
		
		return .ok(.text("\(os) " +
		               "(\(version.majorVersion).\(version.minorVersion).\(version.patchVersion))"))
	}
	
}
