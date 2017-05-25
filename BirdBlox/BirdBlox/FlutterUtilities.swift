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

let SET = getUnicode("s")
let SERVO = getUnicode("s")
let COMMA = getUnicode(",")
let READ = getUnicode("r")

let END: UInt8 = 0x0D

let set = "s"
let led = "l"
let end = "\r"
let BUZZ = "z"

/**
    Gets a command that sets a servo on the flutter
    Note: angle should be between 0 and 180
 */
public func getFlutterServoCommand(_ port: UInt8, angle: UInt8) ->Data {
    let uniPort: UInt8 = getUnicode(port)
    let bounded_angle = bound(angle, min: 0, max: 180)
    let bytes = UnsafePointer<UInt8>([SET, SERVO, uniPort, COMMA, bounded_angle, END])
    return Data(bytes: bytes, count: 6)
}

/**
    Gets a command that sets an LED on the flutter
 */
public func getFlutterLedCommand(_ port: UInt8, r: UInt8, g: UInt8, b: UInt8) -> Data {
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
public func getFlutterBuzzerCommand(vol: Int, freq: Int) -> Data {
	let boundedVol = bound(vol, min: 0, max: 100)
	let boundedFreq = UInt16(bound(freq, min: 0, max: 20000))
	
	let vfHexString = String(format: "%x,%x", boundedVol, boundedFreq)
	let commandString = (set + BUZZ + "," + vfHexString + end)
	
	return Data(bytes: [UInt8](commandString.utf8), count: commandString.utf8.count)
}

/**
    Gets a command that polls the Flutter's inputs
 */
public func getFlutterRead() -> Data {
    let letter: UInt8 = getUnicode("r")
    let end: UInt8 = 0x0D
    return Data(bytes: UnsafePointer<UInt8>([letter, end] as [UInt8]), count: 2)
}

/**
    Gets the response character for the Flutter
 */
public func getFlutterResponseChar() -> UInt8 {
    return READ
}
