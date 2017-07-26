//
//  FlutterUtilities.swift
//  BirdBlox
//
//  Created by birdbrain on 4/3/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//
//
// This file provides utility functions for interacting with the Flutter
//

import Foundation

class BBTFlutterUtility {

	static let set = "s"
	static let led = "l"
	static let servo = "s"
	static let read = "r"
	static let end = "\r"
	static let BUZZ = "z"

	/**
		Gets a command that sets a servo on the flutter
		Note: angle should be between 0 and 180
	 */
	public static func servoCommand(_ port: UInt8, angle: UInt8) ->Data {
		let bounded_angle = bound(angle, min: 0, max: 180)
		let angleHexString = String(format: "%x", bounded_angle)
		let commandString = (set + servo + "\(port)," + angleHexString + end)
		return Data(bytes: [UInt8](commandString.utf8), count: commandString.utf8.count)
	}

	/**
		Gets a command that sets an LED on the flutter
	 */
	public static func ledCommand(_ port: UInt8, r: UInt8, g: UInt8, b: UInt8) -> Data {
		let bounded_r = bound(r, min: 0, max: 100)
		let bounded_g = bound(g, min: 0, max: 100)
		let bounded_b = bound(b, min: 0, max: 100)
		
		let rgbHexString = String(format: "%x,%x,%x", bounded_r, bounded_g, bounded_b)
		let commandString = (set + led + "\(port)," + rgbHexString + end)
		
		return Data(bytes: [UInt8](commandString.utf8), count: commandString.utf8.count)
	}

	/**
		Gets a command that sets the buzzer on the flutter
		Volume should be 0 to 100
	*/
	public static func buzzerCommand(vol: Int, freq: Int) -> Data {
		let boundedVol = bound(vol, min: 0, max: 100)
		let boundedFreq = UInt16(bound(freq, min: 0, max: 20000))
		
		let vfHexString = String(format: "%x,%x", boundedVol, boundedFreq)
		let commandString = (set + BUZZ + "," + vfHexString + end)
		
		return Data(bytes: [UInt8](commandString.utf8), count: commandString.utf8.count)
	}

	/**
		Gets a command that polls the Flutter's inputs
	 */
	public static var readCommand: Data {
		let commandString = read + end
		return Data(bytes: [UInt8](commandString.utf8), count: commandString.utf8.count)
	}
	
	public static var turnOffCommand: Data {
		return BBTHummingbirdUtility.getTurnOffCommand()
	}

	static let responseCharacter = getUnicode(Character("r"))
	
	public static let servoOffAngle = BBTHummingbirdUtility.servoOffAngle
}
