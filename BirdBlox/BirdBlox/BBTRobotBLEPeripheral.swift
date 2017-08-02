//
//  BBTRobotBLEPeripheral.swift
//  BirdBlox
//
//  Created by Jeremy Huang on 2017-07-17.
//  Copyright © 2017年 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import CoreBluetooth

enum BBTRobotType {
	case Hummingbird, Flutter, Finch
	
	var scanningUUID: CBUUID {
		switch self {
		case .Hummingbird:
			return HummingbirdPeripheral.deviceUUID
		case .Flutter:
			return FlutterPeripheral.deviceUUID
		case .Finch:
			return FinchPeripheral.deviceUUID
		default:
			return CBUUID()
		}
	}
	
	static func fromString(_ s: String) -> BBTRobotType? {
		switch s {
		case "hummingbird",
		     "Hummingbird",
			 "HB",
			 "HM":
			return .Hummingbird
		case "Flutter",
		     "flutter",
		     "FL",
		     "fl":
			return .Flutter
		case "Finch",
		     "finch":
			return .Finch
		default:
			return nil
		}
	}
}

protocol BBTRobotBLEPeripheral {
	static var deviceUUID: CBUUID { get }
	
	var peripheral: CBPeripheral { get }
	var id: String { get }
	static var type: BBTRobotType { get }
	
	var initialized: Bool { get }
	var connected: Bool { get }
	
	var sensorValues: [UInt8] { get }
	
	//Both Flutters and Hummingbirds have these
	//Set commands take a port and value, and return a success value
	func setTriLED(port: UInt, intensities: BBTTriLED) -> Bool
	func setServo(port: UInt, angle: UInt8) -> Bool
	
	func setAllOutputsToOff() -> Bool
	
	func endOfLifeCleanup() -> Bool
	
	//The completion will be called once the peripheral has been completely initialized and 
	//is ready to send and receive commands. 
	//This is not guaranteed to occur immediately after the init returns.
	init(peripheral: CBPeripheral, completion: ((BBTRobotBLEPeripheral) -> Void)?)
	
	var description: String { get }
}
