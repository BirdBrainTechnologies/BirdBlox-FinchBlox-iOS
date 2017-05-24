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
let LED = getUnicode("l")
let SERVO = getUnicode("s")
let COMMA = getUnicode(",")
let READ = getUnicode("r")
let BUZZFREQ = getUnicode("f")
let BUZZVOLU = getUnicode("v")
let BUZZ = getUnicode("z")
let END: UInt8 = 0x0D

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
    let uniPort = getUnicode(port)
    let bounded_r = bound(r, min: 0, max: 100)
    let bounded_g = bound(g, min: 0, max: 100)
    let bounded_b = bound(b, min: 0, max: 100)
    let bytes = UnsafePointer<UInt8>([SET, LED, uniPort, COMMA, bounded_r, COMMA, bounded_g, COMMA, bounded_b, END])
    return Data(bytes: bytes, count: 10)
}

/**
	Gets a command that sets the buzzer on the flutter
	Volume should be 0 to 100
*/
public func getFlutterBuzzerCommand(vol: UInt8, freq: UInt16) -> Data {
	let boundedVol = bound(vol, min: 0, max: 100)
	let boundedFreq = UInt16(bound(Int(freq), min: 0, max: 20000))
	let boundedFreqLower = UInt8(boundedFreq & 0xFF)
	let boundedFreqUpper = UInt8((boundedFreq >> 8) & 0xFF)
	let bytes = UnsafePointer<UInt8>([SET, BUZZ, boundedVol, COMMA, boundedFreqLower, boundedFreqUpper, END])
	return Data(bytes: bytes, count: 7)
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
