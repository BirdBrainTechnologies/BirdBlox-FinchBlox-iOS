//
//  SeverRequestPaths.swift
//  BirdBlox
//
//  Created by Jeremy Huang on 2017-05-30.
//  Copyright © 2017年 Birdbrain Technologies LLC. All rights reserved.
//
/*
import Foundation


//Currently keeping the commands with their respective files, so this centralized location for
//Server commands is not used.
//There is also a way to do this using a Strings file and a lookup table/localization -J
struct BBTServerRequestPaths {
	//Requests to load parts of the frontend
	public static let frontEndResource = "/DragAndDrop/:path1/:path2/:path3"
	
	//Requests for hummingbird devices
	public static let discoverHB = "/hummingbird/discover"
	public static let getTotalStatusHB = "/hummingbird/totalStatus"
	public static let connectHB = "/hummingbird/:name/connect"
	public static let disconnectHB = "/hummingbird/:name/disconnect"
	public static let setLedHB = "/hummingbird/:name/out/led/:port/:intensity"
	public static let setTriledHB = "/hummingbird/:name/out/triled/:port/:red/:green/:blue"
	public static let setVibrationHB = "/hummingbird/:name/out/vibration/:port/:intensity"
	public static let setServoHB = "/hummingbird/:name/out/servo/:port/:angle"
	public static let setMotorHB = "/hummingbird/:name/out/motor/:port/:speed"
	public static let getSensorHB = "/hummingbird/:name/in/:sensor/:port"
	
	
	
	//Just saving this in case it is ever wanted
//	server[BBTServerRequestPaths.discoverHB] = hummingbirdManager.discoverRequest
//	server[BBTServerRequestPaths.getTotalStatusHB] = hummingbirdManager.totalStatusRequest
//	
//	server[BBTServerRequestPaths.connectHB] = hummingbirdManager.connectRequest
//	server[BBTServerRequestPaths.disconnectHB] = hummingbirdManager.disconnectRequest
//	
//	server[BBTServerRequestPaths.setLedHB] = hummingbirdManager.setLEDRequest
//	server[BBTServerRequestPaths.setTriledHB] = hummingbirdManager.setTriLedRequest
//	server[BBTServerRequestPaths.setVibrationHB] = hummingbirdManager.setVibrationRequest
//	server[BBTServerRequestPaths.setServoHB] = hummingbirdManager.setServoRequest
//	server[BBTServerRequestPaths.setMotorHB] = hummingbirdManager.setMotorRequest
//	
//	server[BBTServerRequestPaths.getSensorHB] = hummingbirdManager.getInput
}
*/
