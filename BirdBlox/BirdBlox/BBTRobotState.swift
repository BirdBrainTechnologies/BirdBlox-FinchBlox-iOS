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
    
    private var period: UInt16 //the period of the note in us
    private var duration: UInt16 //duration of buzz in ms
    
    init(period: UInt16 = 0, duration: UInt16 = 0) {
        self.duration = duration
        self.period = period
    }
    
    //convert to array used to set the Hummingbird Bit buzzer
    func array() -> [UInt8] {
        
        var buzzerArray: [UInt8] = []
        buzzerArray.append( UInt8(period >> 8) )
        buzzerArray.append( UInt8(period & 0x00ff) )
        buzzerArray.append( UInt8(duration >> 8) )
        buzzerArray.append( UInt8(duration & 0x00ff) )
        
        return buzzerArray
    }
    
    static func ==(lhs: BBTBuzzer, rhs: BBTBuzzer) -> Bool {
        return lhs.period == rhs.period && lhs.duration == rhs.duration
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
    public var ledArray: String?
    
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
            self.buzzer = BBTBuzzer()
        }
        if robotType.ledArrayCount == 1 {
            self.ledArray = "S0000000000000000000000000"
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
            
            let array: [UInt8] = [letter,
                                  trileds[0].tuple.0, trileds[0].tuple.1, trileds[0].tuple.2,
                                  trileds[1].tuple.0, trileds[1].tuple.1, trileds[1].tuple.2,
                                  leds[0], leds[1], leds[2], leds[3],
                                  servos[0], servos[1], servos[2], servos[3],
                                  vibrators[0], vibrators[1], adjusted_motors[0], adjusted_motors[1]]
            assert(array.count == 19)
            
            return Data(bytes: UnsafePointer<UInt8>(array), count: array.count)
        case .HummingbirdBit:
        //Set all: 0xCA LED1 Reserved R1 G1 B1 R2 G2 B2 SS1 SS2 SS3 SS4 LED2 LED3 Time us(MSB) Time us(LSB) Time ms(MSB) Time ms(LSB)
            guard let leds = leds, let trileds = trileds, let servos = servos, let buzzer = buzzer else {
                fatalError("Missing information in the hummingbird bit output state")
            }
            
            let letter: UInt8 = 0xCA
            
            let buzzerArray = buzzer.array()
            
            let array: [UInt8] = [letter, leds[0], 0x00,
                                  trileds[0].tuple.0, trileds[0].tuple.1, trileds[0].tuple.2,
                                  trileds[1].tuple.0, trileds[1].tuple.1, trileds[1].tuple.2,
                                  servos[0], servos[1], servos[2], servos[3],
                                  leds[1], leds[2],
                                  buzzerArray[0], buzzerArray[1], buzzerArray[2], buzzerArray[3]]
            assert(array.count == 19)
            
            //NSLog("Set all \(array)")
            return Data(bytes: UnsafePointer<UInt8>(array), count: array.count)
        case .Flutter: return Data()
        case .Finch: return Data()
        case .MicroBit: return Data()
        }
    }
    
    static func ==(lhs: BBTRobotOutputState, rhs: BBTRobotOutputState) -> Bool {
        return (lhs.trileds == rhs.trileds) && (lhs.servos == rhs.servos) &&
            (lhs.leds == rhs.leds) && (lhs.motors == rhs.motors) && (lhs.vibrators == rhs.vibrators) && (lhs.buzzer == rhs.buzzer) && (lhs.ledArray == rhs.ledArray)
    }
}

