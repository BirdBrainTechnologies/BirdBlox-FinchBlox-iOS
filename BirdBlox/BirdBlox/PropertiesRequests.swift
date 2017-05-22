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
		var mmPerPoint : CGFloat = 0.1
		switch UIDevice.current.userInterfaceIdiom {
		case UIUserInterfaceIdiom.pad:
			mmPerPoint = 0.192424
		case UIUserInterfaceIdiom.phone:
			mmPerPoint = 0.0779141
		default:
			mmPerPoint = 0.1
		}
		return p * mmPerPoint
	}
	
	func getPhysicalDims(request: HttpRequest) -> HttpResponse {
		let heightInPoints = UIScreen.main.bounds.height
		let height = mmFromPoints(p: heightInPoints)
		
		let widthInPoints = UIScreen.main.bounds.width
		let width = mmFromPoints(p: widthInPoints)
		
		return .ok(.text("\(width),\(height)"))
	}
	
	
	
	//Function for getting the device model
	//Modified from https://gist.github.com/kapoorsahil/a9253dd4cb1af882a90e
	func platformModelString() -> String {
		if let key = "hw.machine".cString(using: String.Encoding.utf8) {
			var size: Int = 0
			sysctlbyname(key, nil, &size, nil, 0)
			
			var machine = [CChar](repeating:0, count:Int(size))
			sysctlbyname(key, &machine, &size, nil, 0)
			
			return String(cString: machine)
		}
		
		return "Unknown"
	}
}
