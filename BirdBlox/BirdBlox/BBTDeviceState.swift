//
//  BBTHummingbirdModel.swift
//  BirdBlox
//
//  Created by Jeremy Huang on 2017-06-15.
//  Copyright © 2017年 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation

protocol BBTDeviceOutputState {
	typealias TriLED = (red: UInt8, green: UInt8, blue: UInt8)
	
	var trileds: FixedLengthArray<TriLED> { get }
	var servos: FixedLengthArray<UInt8> { get }
	
	static var triledCount: UInt { get }
	static var servoCount: UInt { get }
}


struct BBTHummingbirdOutputState: BBTDeviceOutputState {
	static let triledCount: UInt = 2
	static let servoCount: UInt = 4
	static let ledCount: UInt = 4
	static let motorCount: UInt = 2
	static let vibratorCount: UInt = 2

	public var trileds: FixedLengthArray<BBTDeviceOutputState.TriLED>
	public var servos: FixedLengthArray<UInt8>
	public var leds: FixedLengthArray<UInt8>
	public var motors: FixedLengthArray<Int8>
	public var vibrators: FixedLengthArray<UInt8>
	
	init(led1: UInt8 = 0, led2: UInt8 = 0, led3: UInt8 = 0, led4: UInt8 = 0,
	     triled1: TriLED = (0,0,0), triled2: TriLED = (0,0,0),
	     servo1: UInt8 = 255, servo2: UInt8 = 255, servo3: UInt8 = 255, servo4: UInt8 = 255,
	     motor1: Int8 = 0, motor2: Int8 = 0,
	     vibrator1: UInt8 = 0, vibrator2: UInt8 = 0){
		
		self.leds = FixedLengthArray([led1, led2, led3, led4])
		self.trileds = FixedLengthArray([triled1, triled2])
		self.servos = FixedLengthArray([servo1, servo2, servo3, servo4])
		self.motors = FixedLengthArray([motor1, motor2])
		self.vibrators = FixedLengthArray([vibrator1, vibrator2])
	}
}

struct BBTFlutterOutputState: BBTDeviceOutputState {
	typealias Buzzer = (frequency: UInt, volume: UInt)
	
	static let triledCount: UInt = 2
	static let servoCount: UInt = 3
	static let buzzerCount: UInt = 1
	
	public var trileds: FixedLengthArray<BBTDeviceOutputState.TriLED>
	public var servos: FixedLengthArray<UInt8>
	public var buzzers: FixedLengthArray<Buzzer>
	
	init(triled1: TriLED = (0,0,0), triled2: TriLED = (0,0,0), Triled3: TriLED = (0,0,0),
	     servo1: UInt8 = 255, servo2: UInt8 = 255, servo3: UInt8 = 255,
	     buzzer1: Buzzer = (0, 0)){
		
		self.trileds = FixedLengthArray([triled1, triled2])
		self.servos = FixedLengthArray([servo1, servo2, servo3])
		self.buzzers = FixedLengthArray([buzzer1])
	}
}
