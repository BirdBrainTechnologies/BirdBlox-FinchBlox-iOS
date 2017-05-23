//
//  PropertiesRequests.swift
//  BirdBlox
//
//  Created by Jeremy Huang on 2017-05-22.
//  Copyright © 2017年 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import Swifter

class PropertiesRequests: NSObject {

	func loadRequests(server: inout HttpServer){
		server["/properties/dims"] = self.getPhysicalDims
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
		
		return .ok(.text("\(width),\(height)"))
	}
	
}
