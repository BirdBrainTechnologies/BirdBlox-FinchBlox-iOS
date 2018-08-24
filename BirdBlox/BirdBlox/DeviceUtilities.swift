//
//  DeviceUtilities.swift
//  BirdBlox
//
//  Created by Jeremy Huang on 2017-05-22.
//  Copyright © 2017年 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import UIKit


public let BBTLocalHostIP = "127.0.0.1"

public struct BBTThisIDevice {
	//Function for getting the device model
	//Modified from https://gist.github.com/kapoorsahil/a9253dd4cb1af882a90e
	static func platformModelString() -> String {
		if let key = "hw.machine".cString(using: String.Encoding.utf8) {
			var size: Int = 0
			sysctlbyname(key, nil, &size, nil, 0)
			
			var machine = [CChar](repeating:0, count:Int(size))
			sysctlbyname(key, &machine, &size, nil, 0)
			
			return String(cString: machine)
		}
		
		return "Unknown"
	}
	
	
	static func milimetersPerPointFor(deviceModel: String) -> CGFloat {
		switch deviceModel {
		//iPhone, iPod Touch, iPad Mini are 163 points per inch
		case "iPhone1,1",
			"iPhone1,2",
			"iPhone2,1",
			"iPhone3,1",
			"iPhone3,3",
			"iPhone4,1",
			"iPhone5,1",
			"iPhone5,2",
			"iPhone5,3",
			"iPhone5,4",
			"iPhone6,1",
			"iPhone6,2",
			"iPhone7,2",
			"iPhone8,4",
			"iPhone9,1",
			"iPhone9,3",
		
			"iPod1,1",
			"iPod2,1",
			"iPod3,1",
			"iPod4,1",
			"iPod5,1",
		
			"iPad2,5",
			"iPad2,6",
			"iPad2,7",
			"iPad4,4",
			"iPad4,5",
			"iPad4,6",
			"iPad4,7",
			"iPad4,8",
			"iPad4,9":     return 0.15582822085499998
		
		//iPhone Plus is 200.5 points per inch
		case "iPhone7,1":   return 0.1266832917688
		case "iPhone8,2":   return 0.1266832917688
		case "iPhone9,2":   return 0.1266832917688
		case "iPhone9,4":   return 0.1266832917688
		
		//iPad and iPad Pro are 132 points per inch
		case "iPad1,1",
			"iPad2,1",
			"iPad2,2",
			"iPad2,3",
			"iPad2,4",
			"iPad3,1",
			"iPad3,2",
			"iPad3,3",
			"iPad3,4",
			"iPad3,5",
			"iPad3,6",
			"iPad4,1",
			"iPad4,2",
			"iPad4,3",
			"iPad5,3",
			"iPad5,4":     return 0.1924242424304
		
		//Simulators
		case "i386":        return 0.15582822085499998
		case "x86_64":      return 0.15582822085499998
		default:
			switch deviceModel.substring(to: deviceModel.index(deviceModel.startIndex, offsetBy: 3)) {
				case "iPa": return 0.1924242424304
				case "iPo",
				     "iPh": return 0.15582822085499998
				default:    return 0.15582822085499998
			}
		}
	}
}
