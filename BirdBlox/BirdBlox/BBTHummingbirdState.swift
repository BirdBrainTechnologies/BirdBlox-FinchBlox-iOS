//
//  BBTHummingbirdModel.swift
//  BirdBlox
//
//  Created by Jeremy Huang on 2017-06-15.
//  Copyright © 2017年 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation

struct BBTHummingbirdState {
	public typealias TriLED = (red: UInt8, green: UInt8, blue: UInt8)
	
	public let leds: (UInt8, UInt8, UInt8, UInt8)
	public let trileds: (TriLED, TriLED)
	public let servos: (UInt8, UInt8, UInt8, UInt8)
	public let motors: (Int8, Int8)
	public let vibrators: (UInt8, UInt8)
	
	init(led1: UInt8 = 0, led2: UInt8 = 0, led3: UInt8 = 0, led4: UInt8 = 0,
	     triled1: TriLED = (0, 0, 0), triled2: TriLED = (0, 0, 0),
		 servo1: UInt8 = 0, servo2: UInt8 = 0, servo3: UInt8 = 0, servo4: UInt8 = 0,
		 motor1: Int8 = 0, motor2: Int8 = 0,
		 vibrator1: UInt8 = 0, vibrator2: UInt8 = 0){
		
		self.leds = (led1, led2, led3, led4)
		self.trileds = (triled1, triled2)
		self.servos = (servo1, servo2, servo3, servo4)
		self.motors = (motor1, motor2)
		self.vibrators = (vibrator1, vibrator2)
	}
	
	init(leds: (UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0),
	     trileds: (TriLED, TriLED) = ((0, 0, 0), (0, 0, 0)),
	     servos: (UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0),
		 motors: (Int8, Int8) = (0, 0),
	     vibrators: (UInt8, UInt8) = (0, 0)) {
		
		self.leds = leds
		self.trileds = trileds
		self.servos = servos
		self.motors = motors
		self.vibrators = vibrators
	}
	
	var mutableCopy: BBTMutableHummingbirdState {
		return BBTMutableHummingbirdState(led1: self.leds.0, led2: self.leds.1,
		                                  led3: self.leds.2, led4: self.leds.3,
										  triled1: self.trileds.0, triled2: self.trileds.1,
										  servo1: self.servos.0, servo2: self.servos.1,
										  servo3: self.servos.2, servo4: self.servos.3,
										  motor1: self.motors.0, motor2: self.motors.1,
										  vibrator1: self.vibrators.0, vibrator2: self.vibrators.1)
	}
	
	static func allStopState(from model: BBTHummingbirdState) -> BBTHummingbirdState {
		return BBTHummingbirdState(servos: model.servos)
	}
	
	static func triLed(_ left: TriLED, equalTo right: TriLED) -> Bool {
		return (left.blue == right.blue) && (left.green == right.green) &&
			(left.red == right.red)
	}
	
	static func == (left: BBTHummingbirdState, right: BBTHummingbirdState) -> Bool {
		return (left.leds == right.leds) && triLed(left.trileds.0, equalTo: right.trileds.0) &&
			triLed(left.trileds.1, equalTo: right.trileds.1) &&
			(left.servos == right.servos) && (left.motors == right.motors) &&
			(left.vibrators == right.vibrators)
	}
}


struct BBTMutableHummingbirdState {
	public typealias TriLED = BBTHummingbirdState.TriLED
	
	public var leds: [UInt8]
	public var trileds: [TriLED]
	public var servos: [UInt8]
	public var motors: [Int8]
	public var vibrators: [UInt8]
	
	init(led1: UInt8 = 0, led2: UInt8 = 0, led3: UInt8 = 0, led4: UInt8 = 0,
	     triled1: TriLED = (0,0,0), triled2: TriLED = (0,0,0),
	     servo1: UInt8 = 0, servo2: UInt8 = 0, servo3: UInt8 = 0, servo4: UInt8 = 0,
	     motor1: Int8 = 0, motor2: Int8 = 0,
	     vibrator1: UInt8 = 0, vibrator2: UInt8 = 0){
		
		self.leds = [led1, led2, led3, led4]
		self.trileds = [triled1, triled2]
		self.servos = [servo1, servo2, servo3, servo4]
		self.motors = [motor1, motor2]
		self.vibrators = [vibrator1, vibrator2]
	}
	
	
	public var immutableCopy: BBTHummingbirdState {
		return BBTHummingbirdState(led1: self.leds[0], led2: self.leds[1],
		                           led3: self.leds[2], led4: self.leds[3],
								   triled1: self.trileds[0], triled2: self.trileds[1],
								   servo1: self.servos[0], servo2: self.servos[1],
								   servo3: self.servos[2], servo4: self.servos[3],
								   motor1: self.motors[0], motor2: self.motors[1],
								   vibrator1: self.vibrators[0], vibrator2: self.vibrators[1])
	}
}
