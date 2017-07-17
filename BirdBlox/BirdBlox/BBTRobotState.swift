//
//  BBTHummingbirdModel.swift
//  BirdBlox
//
//  Created by Jeremy Huang on 2017-06-15.
//  Copyright © 2017年 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation

//Have to make a TriLED struct because Tuples are not Equatable :( –J
struct BBTTriLED: Equatable {
	public let red: UInt8
	public let green: UInt8
	public let blue: UInt8
	
	init(_ intensities: (red: UInt8, green: UInt8, blue: UInt8)) {
		red = intensities.red
		green = intensities.green
		blue = intensities.blue
	}
	
	init(_ inRed: UInt8, _ inGreen: UInt8, _ inBlue: UInt8) {
		red = inRed
		green = inGreen
		blue = inBlue
	}
	
	var tuple: (red: UInt8, green: UInt8, blue: UInt8) {
		return (red: red, green: green, blue: blue)
	}
	
	static func ==(lhs: BBTTriLED, rhs: BBTTriLED) -> Bool {
		return lhs.red == rhs.red && lhs.green == rhs.green && lhs.blue == rhs.blue
	}
}

protocol BBTRobotOutputState: Equatable {
	typealias TriLED = BBTTriLED
	
	var trileds: FixedLengthArray<TriLED> { get }
	var servos: FixedLengthArray<UInt8> { get }
	
	static var triledCount: UInt { get }
	static var servoCount: UInt { get }
}


struct BBTHummingbirdOutputState: BBTRobotOutputState {
	static let triledCount: UInt = 2
	static let servoCount: UInt = 4
	static let ledCount: UInt = 4
	static let motorCount: UInt = 2
	static let vibratorCount: UInt = 2
	
	public var trileds: FixedLengthArray<TriLED>
	public var servos: FixedLengthArray<UInt8>
	public var leds: FixedLengthArray<UInt8>
	public var motors: FixedLengthArray<Int8>
	public var vibrators: FixedLengthArray<UInt8>
	
	init(led1: UInt8 = 0, led2: UInt8 = 0, led3: UInt8 = 0, led4: UInt8 = 0,
	     triled1: TriLED = BBTTriLED(0,0,0), triled2: TriLED = BBTTriLED(0,0,0),
	     servo1: UInt8 = 255, servo2: UInt8 = 255, servo3: UInt8 = 255, servo4: UInt8 = 255,
	     motor1: Int8 = 0, motor2: Int8 = 0,
	     vibrator1: UInt8 = 0, vibrator2: UInt8 = 0){
		
		self.leds = FixedLengthArray([led1, led2, led3, led4])
		self.trileds = FixedLengthArray([triled1, triled2])
		self.servos = FixedLengthArray([servo1, servo2, servo3, servo4])
		self.motors = FixedLengthArray([motor1, motor2])
		self.vibrators = FixedLengthArray([vibrator1, vibrator2])
	}
	
	static func ==(lhs: BBTHummingbirdOutputState, rhs: BBTHummingbirdOutputState) -> Bool {
		return (lhs.trileds == rhs.trileds) && (lhs.servos == rhs.servos) &&
			(lhs.leds == rhs.leds) && (lhs.motors == rhs.motors) && (lhs.vibrators == rhs.vibrators)
	}
}

struct BBTFlutterOutputState: BBTRobotOutputState {
	struct Buzzer: Equatable {
		let frequecy: UInt
		let volume: UInt
		
		init(_ freq: UInt, _ vol: UInt) {
			frequecy = freq
			volume = vol
		}
		
		static func ==(lhs: Buzzer, rhs: Buzzer) -> Bool {
			return lhs.frequecy == rhs.frequecy	&& lhs.volume == rhs.volume
		}
	}
	
	static let triledCount: UInt = 2
	static let servoCount: UInt = 3
	static let buzzerCount: UInt = 1
	
	public var trileds: FixedLengthArray<BBTRobotOutputState.TriLED>
	public var servos: FixedLengthArray<UInt8>
	public var buzzers: FixedLengthArray<Buzzer>
	
	init(triled1: TriLED = BBTTriLED(0,0,0), triled2: TriLED = BBTTriLED(0,0,0),
	     Triled3: TriLED = BBTTriLED(0,0,0),
	     servo1: UInt8 = 255, servo2: UInt8 = 255, servo3: UInt8 = 255,
	     buzzer1: Buzzer = Buzzer(0, 0)){
		
		self.trileds = FixedLengthArray([triled1, triled2])
		self.servos = FixedLengthArray([servo1, servo2, servo3])
		self.buzzers = FixedLengthArray([buzzer1])
	}
	
	/// Returns a Boolean value indicating whether two values are equal.
	///
	/// Equality is the inverse of inequality. For any values `a` and `b`,
	/// `a == b` implies that `a != b` is `false`.
	///
	/// - Parameters:
	///   - lhs: A value to compare.
	///   - rhs: Another value to compare.
	static func ==(lhs: BBTFlutterOutputState, rhs: BBTFlutterOutputState) -> Bool {
		return lhs.buzzers == rhs.buzzers && lhs.servos == rhs.servos && lhs.trileds == rhs.trileds
	}
}
