//
//  HummingbirdUtilities.swift
//  BirdBlox
//
//  Created by birdbrain on 4/3/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//
//
// This file provides utility functions for interacting with the Hummingbird
//

import Foundation

class BBTHummingbirdUtility {
	/**
		Gets a command to set an LED on the hummingbird
	 */
	static public func getLEDCommand(_ port: UInt8, intensity: UInt8) -> Data{
		let real_port: UInt8 = getUnicode(port-1)
		let letter: UInt8 = 0x4C
		let bounded_intensity = bound(intensity, min: 0, max: 100)
		let real_intensity = UInt8(floor(Double(bounded_intensity)*2.55))
		return Data(bytes: UnsafePointer<UInt8>([letter, real_port, real_intensity] as [UInt8]), count: 3)
	}

	/**
	 Gets a command to set a tri-LED on the hummingbird
	 */
	static public func getTriLEDCommand(_ port: UInt8, red_val: UInt8, green_val: UInt8, blue_val: UInt8) ->Data{
		let real_port: UInt8 = getUnicode(port-1)
		let letter: UInt8 = 0x4F
		let bounded_red = bound(red_val, min: 0, max: 100)
		let real_red = UInt8(floor(Double(bounded_red)*2.55))
		let bounded_green = bound(green_val, min: 0, max: 100)
		let real_green = UInt8(floor(Double(bounded_green)*2.55))
		let bounded_blue = bound(blue_val, min: 0, max: 100)
		let real_blue = UInt8(floor(Double(bounded_blue)*2.55))
		return Data(bytes: UnsafePointer<UInt8>([letter, real_port, real_red, real_green, real_blue] as [UInt8]), count: 5)
	}

	/**
		Gets a command to set a motor on the hummingbird
		Note: speed should range from -100 to 100
	 */
	static public func getMotorCommand(_ port: UInt8, speed: Int) -> Data{
		var direction: UInt8 = 0
		let real_port: UInt8 = getUnicode(port-1)
		let letter: UInt8 = 0x4D
		var real_speed: UInt8 = 0
		let bounded_speed: Int = bound(abs(speed), min: 0, max: 100)
		if (speed < 0){
			direction = 1
			real_speed = UInt8(floor(Double(bounded_speed)*2.55))
		}
		else{
			real_speed = UInt8(floor(Double(bounded_speed)*2.55))
		}
		let real_direction: UInt8 = getUnicode(direction)
		return Data(bytes: UnsafePointer<UInt8>([letter, real_port, real_direction, real_speed] as [UInt8]), count: 4)
	}

	/**
		Gets a command to set a vibration motor on the hummingbird
	 */
	static public func getVibrationCommand(_ port: UInt8, intensity: UInt8) -> Data{
		let real_port: UInt8 = getUnicode(port-1)
		let letter: UInt8 = 0x56
		let bounded_intensity = bound(intensity, min: 0, max: 100)
		let real_intensity: UInt8 = UInt8(floor(Double(bounded_intensity)*2.55))
		return Data(bytes: UnsafePointer<UInt8>([letter, real_port, real_intensity] as [UInt8]), count: 3)
	}

	/**
		Gets a command to set a servo motor on the hummingbird
		Note: angle should be between 0 and 180
	 */
	static public func getServoCommand(_ port: UInt8, angle: UInt8) -> Data{
		let real_port: UInt8 = getUnicode(port-1)
		let letter: UInt8 = 0x53
		let bounded_angle = bound(angle, min: 0, max: 180)
		let real_angle = UInt8(floor(Double(bounded_angle)*1.25))
		return Data(bytes: UnsafePointer<UInt8>([letter, real_port, real_angle] as [UInt8]), count: 3)
	}

	/**
		This gets a command to set all the outputs of a hummingbird
		As input it takes in arrays from the HummingbirdPeripheral class
	 */
	static public func getSetAllCommand(tris: ((red: UInt8, green: UInt8, blue: UInt8),
										(red: UInt8, green: UInt8, blue: UInt8)),
								 leds: (UInt8, UInt8, UInt8, UInt8),
								 servos: (UInt8, UInt8, UInt8, UInt8),
								 motors: (Int8, Int8),
								 vibs: (UInt8, UInt8)) -> Data {
		let letter: UInt8 = 0x41
		
		var adjusted_motors: [UInt8] = [0,0]
		if motors.0 < 0 {
			adjusted_motors[0] = UInt8(bound(-(Int)(motors.0), min: -100, max: 100)) + 128
		} else {
			adjusted_motors[0] = UInt8(motors.0)
		}
		if motors.1 < 0 {
			adjusted_motors[1] = UInt8(bound(-(Int)(motors.1), min: -100, max: 100)) + 128
		} else {
			adjusted_motors[1] = UInt8(motors.1)
		}
		
		
		let adjustServo: ((UInt8) -> UInt8) = { ($0 > 180) ? 255 : $0 + ($0 >> 2) }
		
		let servosFull = (adjustServo(servos.0), adjustServo(servos.1),
						  adjustServo(servos.2), adjustServo(servos.3))
		
		let array: [UInt8] = [letter, tris.0.0, tris.0.1, tris.0.2, tris.1.0, tris.1.1, tris.1.2,
							  leds.0, leds.1, leds.2, leds.3,
							  servosFull.0, servosFull.1, servosFull.2, servosFull.3,
							  vibs.0, vibs.1, adjusted_motors[0], adjusted_motors[1]]
		assert(array.count == 19)
		
		return Data(bytes: UnsafePointer<UInt8>(array), count: array.count)
	}

	/**
		Gets the command to reset the hummingbird
	 */
	static public func getResetCommand() -> Data{
		let letter: UInt8 = 0x52
		return Data(bytes: UnsafePointer<UInt8>([letter] as [UInt8]), count: 1)
	}

	/**
		Gets the command to turn off all the outputs on the hummingbird
	 */
	static public func getTurnOffCommand() -> Data{
		let letter: UInt8 = 0x58
		return Data(bytes: UnsafePointer<UInt8>([letter] as [UInt8]), count: 1)
	}

	/**
		Gets the hummingbird ping command.
	 */
	static public func getZCommand() -> Data{
		let letter: UInt8 = 0x7A
		return Data(bytes: UnsafePointer<UInt8>([letter] as [UInt8]), count: 1)
	}

	/**
		Gets the command to poll the sensors on the hummingbird once
	 */
	static public func getPollSensorsCommand() -> Data{
		let letter: UInt8 = 0x47
		let num: UInt8 = getUnicode(UInt8(3))
		return Data(bytes: UnsafePointer<UInt8>([letter,num] as [UInt8]), count: 2)
	}

	/**
	 Gets the command to start the sensor polling on the hummingbird
	 */
	static public func getPollStartCommand() -> Data{
		let letter: UInt8 = 0x47
		let num: UInt8 = getUnicode(UInt8(5))
		return Data(bytes: UnsafePointer<UInt8>([letter,num] as [UInt8]), count: 2)
	}

	/**
	 Gets the command to stop the sensor polling on the hummingbird
	 */
	static public func getPollStopCommand() -> Data{
		let letter: UInt8 = 0x47
		let num: UInt8 = getUnicode(UInt8(6))
		return Data(bytes: UnsafePointer<UInt8>([letter,num] as [UInt8]), count: 2)
	}
	
	static let servoOffAngle: UInt8 = 255
}
