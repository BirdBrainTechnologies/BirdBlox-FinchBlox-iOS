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
		if request.address == nil || request.address != BBTLocalHostIP{
			#if DEBUG
				let address = request.address ?? "unknown"
				NSLog("Physical Dimesions requested from external address \(address)")
				print(request.params)
				print(request.queryParams)
				print(request.method)
				print(request.path)
			#else
				return .forbidden
			#endif
		}
	
		let heightInPoints = UIScreen.main.bounds.height
		let height = mmFromPoints(p: heightInPoints)
		
		let widthInPoints = UIScreen.main.bounds.width
		let width = mmFromPoints(p: widthInPoints)
		
		return .ok(.text("\(width),\(height)"))
	}
	
	func getVersion(request: HttpRequest) -> HttpResponse {
		if request.address == nil || request.address != BBTLocalHostIP{
			#if DEBUG
				let address = request.address ?? "unknown"
				NSLog("Version requested from external address \(address)")
			#else
				return .forbidden
			#endif
		}
		
		let os = "iOS"
		let version = ProcessInfo().operatingSystemVersion
		
		return .ok(.text("\(os) " +
		               "(\(version.majorVersion).\(version.minorVersion).\(version.patchVersion))"))
	}
	
}
