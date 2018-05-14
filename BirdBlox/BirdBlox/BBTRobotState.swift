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
struct BBTBuzzer: Equatable {
    let frequecy: UInt
    let volume: UInt
    
    init(_ freq: UInt, _ vol: UInt) {
        frequecy = freq
        volume = vol
    }
    
    static func ==(lhs: BBTBuzzer, rhs: BBTBuzzer) -> Bool {
        return lhs.frequecy == rhs.frequecy    && lhs.volume == rhs.volume
    }
}

struct BBTRobotOutputState: Equatable {
    
    let robotType: BBTRobotType
    
    public var trileds: FixedLengthArray<BBTTriLED>?
    public var servos: FixedLengthArray<UInt8>?
    public var leds: FixedLengthArray<UInt8>?
    public var motors: FixedLengthArray<Int8>?
    public var vibrators: FixedLengthArray<UInt8>?
    public var buzzer: BBTBuzzer?
    
    init(robotType: BBTRobotType) {
        self.robotType = robotType
        
        if robotType.triledCount > 0 {
            self.trileds = FixedLengthArray(length: robotType.triledCount, repeating: BBTTriLED(0,0,0))
        }
        
        if robotType.servoCount > 0 {
            self.servos = FixedLengthArray(length: robotType.servoCount, repeating: UInt8(255))
        }
        
        if robotType.ledCount > 0 {
            self.leds = FixedLengthArray(length: robotType.ledCount, repeating: UInt8(0))
        }
        
        if robotType.motorCount > 0 {
            self.motors = FixedLengthArray(length: robotType.motorCount, repeating: Int8(0))
        }
        
        if robotType.vibratorCount > 0 {
            self.vibrators = FixedLengthArray(length: robotType.vibratorCount, repeating: UInt8(0))
        }
            
        if robotType.buzzerCount == 1 {
            buzzer = BBTBuzzer(0, 0)
        }
    }
    
    func setAllCommand() -> Data {
        switch robotType {
        case .Hummingbird:
            let letter: UInt8 = 0x41
            
            guard let motors = motors, let servos = servos, let trileds = trileds,
                let leds = leds, let vibrators = vibrators else {
                fatalError("Missing information in hummingbird output state")
            }
            
            var adjusted_motors: [UInt8] = [0,0]
            if motors[0] < 0 {
                adjusted_motors[0] = UInt8(bound(-(Int)(motors[0]), min: -100, max: 100)) + 128
            } else {
                adjusted_motors[0] = UInt8(motors[0])
            }
            if motors[1] < 0 {
                adjusted_motors[1] = UInt8(bound(-(Int)(motors[1]), min: -100, max: 100)) + 128
            } else {
                adjusted_motors[1] = UInt8(motors[1])
            }
            
            let adjustServo: ((UInt8) -> UInt8) = { ($0 > 180) ? 255 : $0 + ($0 >> 2) }
            
            let servosFull = (adjustServo(servos[0]), adjustServo(servos[1]),
                              adjustServo(servos[2]), adjustServo(servos[3]))
            
            let array: [UInt8] = [letter,
                                  trileds[0].tuple.0, trileds[0].tuple.1, trileds[0].tuple.2,
                                  trileds[1].tuple.0, trileds[1].tuple.1, trileds[1].tuple.2,
                                  leds[0], leds[1], leds[2], leds[3],
                                  servosFull.0, servosFull.1, servosFull.2, servosFull.3,
                                  vibrators[0], vibrators[1], adjusted_motors[0], adjusted_motors[1]]
            assert(array.count == 19)
            
            return Data(bytes: UnsafePointer<UInt8>(array), count: array.count)
        case .HummingbirdBit:
        //Set all: 0xCA LED1 LED4status R1 G1 B1 R2 G2 B2 SS1 SS2 SS3 SS4 LED2 LED3
            guard let leds = leds, let trileds = trileds, let servos = servos else {
                fatalError("Missing information in the hummingbird bit output state")
            }
            
            let letter: UInt8 = 0xCA
            
            let adjustServo: ((UInt8) -> UInt8) = { ($0 > 180) ? 255 : $0 + ($0 >> 2) }
            
            let servosFull = (adjustServo(servos[0]), adjustServo(servos[1]),
                              adjustServo(servos[2]), adjustServo(servos[3]))
            
            let array: [UInt8] = [letter, leds[0], leds[3],
                                  trileds[0].tuple.0, trileds[0].tuple.1, trileds[0].tuple.2,
                                  trileds[1].tuple.0, trileds[1].tuple.1, trileds[1].tuple.2,
                                  servosFull.0, servosFull.1, servosFull.2, servosFull.3,
                                  leds[1], leds[2]]
            assert(array.count == 15)
            
            return Data(bytes: UnsafePointer<UInt8>(array), count: array.count)
        case .Flutter: return Data()
        case .Finch:
        //Set all: 0xDA RGB_R RGB_G RGB_B Dir_L Speed_L Dir_R Speed_R
            guard let trileds = trileds, let motors = motors else {
                fatalError("Missing information in Finch output state")
            }
            
            let letter: UInt8 = 0xDA
            
            var adjusted_motors: [UInt8] = [0,0]
            var motor_dir: [UInt8] = [1,1]
            if motors[0] < 0 {
                motor_dir[0] = 0
                adjusted_motors[0] = UInt8(bound(-(Int)(motors[0]), min: -100, max: 100)) + 128
            } else {
                adjusted_motors[0] = UInt8(motors[0])
            }
            if motors[1] < 0 {
                motor_dir[1] = 0
                adjusted_motors[1] = UInt8(bound(-(Int)(motors[1]), min: -100, max: 100)) + 128
            } else {
                adjusted_motors[1] = UInt8(motors[1])
            }
            
            let array: [UInt8] = [letter,
                                  trileds[0].tuple.0, trileds[0].tuple.1, trileds[0].tuple.2,
                                  motor_dir[0], adjusted_motors[0], motor_dir[1], adjusted_motors[1]]
            assert(array.count == 8)
            
            return Data(bytes: UnsafePointer<UInt8>(array), count: array.count)
        case .MicroBit: return Data()
        }
    }
    
    static func ==(lhs: BBTRobotOutputState, rhs: BBTRobotOutputState) -> Bool {
        return (lhs.trileds == rhs.trileds) && (lhs.servos == rhs.servos) &&
            (lhs.leds == rhs.leds) && (lhs.motors == rhs.motors) && (lhs.vibrators == rhs.vibrators) && (lhs.buzzer == rhs.buzzer)
    }
}

/*
protocol BBTRobotOutputState: Equatable {
	//typealias TriLED = BBTTriLED
    //typealias Buzzer = BBTBuzzer
	
	//var trileds: FixedLengthArray<TriLED> { get }
	//var servos: FixedLengthArray<UInt8> { get }
	
	static var triledCount: UInt { get }
    static var ledCount: UInt { get }
	static var servoCount: UInt { get }
    static var motorCount: UInt { get }
    static var vibratorCount: UInt { get }
    static var buzzerCount: UInt { get }
}


struct BBTHummingbirdOutputState: BBTRobotOutputState {
	static let triledCount: UInt = 2
	static let servoCount: UInt = 4
	static let ledCount: UInt = 4
	static let motorCount: UInt = 2
	static let vibratorCount: UInt = 2
    static let buzzerCount: UInt = 1
	
	public var trileds: FixedLengthArray<BBTTriLED>
	public var servos: FixedLengthArray<UInt8>
	public var leds: FixedLengthArray<UInt8>
	public var motors: FixedLengthArray<Int8>
	public var vibrators: FixedLengthArray<UInt8>
	
	init(led1: UInt8 = 0, led2: UInt8 = 0, led3: UInt8 = 0, led4: UInt8 = 0,
	     triled1: BBTTriLED = BBTTriLED(0,0,0), triled2: BBTTriLED = BBTTriLED(0,0,0),
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

struct BBTFinchOutputState: BBTRobotOutputState {
    static let triledCount: UInt = 1
    static let ledCount: UInt = 0
    static let servoCount: UInt = 0
    static var motorCount: UInt = 2
    static var vibratorCount: UInt = 0
    static var buzzerCount: UInt = 0
    
    public var triled: BBTTriLED
    public var motors: FixedLengthArray<UInt8>
    
    init(triled: BBTTriLED = BBTTriLED(0,0,0), motor1: UInt8 = 0, motor2: UInt8 = 0) {
        self.triled = triled
        self.motors = FixedLengthArray([motor1, motor2])
    }
    
    static func ==(lhs: BBTFinchOutputState, rhs: BBTFinchOutputState) -> Bool {
        return (lhs.triled == rhs.triled) && (lhs.motors == rhs.motors)
    }
}

struct BBTHummingbirdBitOutputState: BBTRobotOutputState {
    static let triledCount: UInt = 2
    static let ledCount: UInt = 29 //?
    static let servoCount: UInt = 4
    static var motorCount: UInt = 0
    static var vibratorCount: UInt = 0
    static var buzzerCount: UInt = 1
    
    public var trileds: FixedLengthArray<BBTTriLED>
    public var leds: FixedLengthArray<UInt8>
    public var servos: FixedLengthArray<UInt8>
    public var buzzer: BBTBuzzer
    
    init(triled1: BBTTriLED = BBTTriLED(0,0,0), triled2: BBTTriLED = BBTTriLED(0,0,0),
         led1: UInt8 = 0, led2: UInt8 = 0, led3: UInt8 = 0, led4: UInt8 = 0,
         servo1: UInt8 = 255, servo2: UInt8 = 255, servo3: UInt8 = 255, servo4: UInt8 = 255,
         ledArray: [UInt8] = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
         buzzer: BBTBuzzer = BBTBuzzer(0, 0)) {
        
        self.trileds = FixedLengthArray([triled1, triled2])
        self.leds = FixedLengthArray([led1, led2, led3, led4] + ledArray)
        self.servos = FixedLengthArray([servo1, servo2, servo3, servo4])
        self.buzzer = buzzer
    }
    
    static func ==(lhs: BBTHummingbirdBitOutputState, rhs: BBTHummingbirdBitOutputState) -> Bool {
        return (lhs.trileds == rhs.trileds) && (lhs.leds == rhs.leds) &&
            (lhs.servos == rhs.servos) && (lhs.buzzer == rhs.buzzer)
    }
}

struct BBTMicroBitOutputState: BBTRobotOutputState {
    static let triledCount: UInt = 0
    static let ledCount: UInt = 25
    static let servoCount: UInt = 0
    static var motorCount: UInt = 0
    static var vibratorCount: UInt = 0
    static var buzzerCount: UInt = 0
    
    public var leds: FixedLengthArray<UInt8>
    
    init(ledArray: [UInt8] = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]){
        self.leds = FixedLengthArray(ledArray)
    }
    
    static func ==(lhs: BBTMicroBitOutputState, rhs: BBTMicroBitOutputState) -> Bool {
        return (lhs.leds == rhs.leds)
    }
}

struct BBTFlutterOutputState: BBTRobotOutputState {
    static let ledCount: UInt = 0
    static let motorCount: UInt = 0
    static var vibratorCount: UInt = 0
	static let triledCount: UInt = 2
	static let servoCount: UInt = 3
	static let buzzerCount: UInt = 1
	
	public var trileds: FixedLengthArray<BBTTriLED>
	public var servos: FixedLengthArray<UInt8>
	public var buzzers: FixedLengthArray<BBTBuzzer>
	
	init(triled1: BBTTriLED = BBTTriLED(0,0,0), triled2: BBTTriLED = BBTTriLED(0,0,0),
	     Triled3: BBTTriLED = BBTTriLED(0,0,0),
	     servo1: UInt8 = 255, servo2: UInt8 = 255, servo3: UInt8 = 255,
	     buzzer1: BBTBuzzer = BBTBuzzer(0, 0)){
		
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
}*/
