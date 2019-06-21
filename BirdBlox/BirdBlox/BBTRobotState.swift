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
    
    //convert to array used to set the buzzer
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
struct BBTMotor: Equatable {
    
    public let velocity: Int8
    private let ticksMSB: UInt8
    private let ticksSSB: UInt8 //second significant byte
    private let ticksLSB: UInt8
    
    init(_ speed: Int8 = 0, _ ticks: Int = 0) {
        //print("creating new Motor state with speed \(speed) and distance \(ticks)")
        velocity = speed
        
        //let ticks = Int(round(distance * 80))
        ticksMSB = UInt8(ticks >> 16)
        ticksSSB = UInt8((ticks & 0x00ff00) >> 8)
        ticksLSB = UInt8(ticks & 0x0000ff)
        //print("motor state created. \(ticks) \(ticksMSB) \(ticksSSB) \(ticksLSB)")
    }
    
    //convert to array used to set the motor
    func array() -> [UInt8] {
        
        let cv:(Int8)->UInt8 = { velocity in
            var v = UInt8(abs(velocity)) //TODO: handle the case where velocity = -128? this will cause an overflow error here
            if velocity > 0 { v += 128 }
            return v
        }
        
        return [cv(velocity), ticksMSB, ticksSSB, ticksLSB]
    }
    
    static func == (lhs: BBTMotor, rhs: BBTMotor) -> Bool {
        return lhs.velocity == rhs.velocity && lhs.ticksLSB == rhs.ticksLSB &&
            lhs.ticksSSB == rhs.ticksSSB && lhs.ticksMSB == rhs.ticksMSB
    }
}

struct BBTRobotOutputState: Equatable {
    
    let robotType: BBTRobotType
    
    public var trileds: FixedLengthArray<BBTTriLED>?
    public var servos: FixedLengthArray<UInt8>?
    public var leds: FixedLengthArray<UInt8>?
    public var motors: FixedLengthArray<BBTMotor>?
    public var vibrators: FixedLengthArray<UInt8>?
    public var buzzer: BBTBuzzer?
    public var ledArray: String?
    public var pins: FixedLengthArray<UInt8>?
    public var mode: [UInt8]? //8 bits
    
    public static let flashSent: String = "CommandFlashSent"
    
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
            self.motors = FixedLengthArray(length: robotType.motorCount, repeating: BBTMotor())
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
        
        if robotType.pinCount > 0 {
            self.pins = FixedLengthArray(length: robotType.pinCount, repeating: UInt8(0))
            self.mode = [0,0,0,0,0,0,0,0]
        }
        
    }
    
    func setAllCommand() -> Data {
        switch robotType {
        case .Hummingbird:
            let letter: UInt8 = 0x41
            
            guard let motors = motors, let servos = servos, let trileds = trileds,
                let leds = leds, let vibrators = vibrators else {
                NSLog("Missing information in hummingbird duo output state")
                return Data()
            }
            
            var adjusted_motors: [UInt8] = [0,0]
            if motors[0].velocity < 0 {
                adjusted_motors[0] = UInt8(bound(-(Int)(motors[0].velocity), min: -100, max: 100)) + 128
            } else {
                adjusted_motors[0] = UInt8(motors[0].velocity)
            }
            if motors[1].velocity < 0 {
                adjusted_motors[1] = UInt8(bound(-(Int)(motors[1].velocity), min: -100, max: 100)) + 128
            } else {
                adjusted_motors[1] = UInt8(motors[1].velocity)
            }
            
            let adjustVib: (UInt8) -> UInt8 = { v in
                let bounded_intensity = bound(v, min: 0, max: 100)
                return UInt8(floor(Double(bounded_intensity)*2.55))
            }
            
            let array: [UInt8] = [letter,
                                  trileds[0].tuple.0, trileds[0].tuple.1, trileds[0].tuple.2,
                                  trileds[1].tuple.0, trileds[1].tuple.1, trileds[1].tuple.2,
                                  leds[0], leds[1], leds[2], leds[3],
                                  servos[0], servos[1], servos[2], servos[3],
                                  adjustVib(vibrators[0]), adjustVib(vibrators[1]),
                                  adjusted_motors[0], adjusted_motors[1]]
            assert(array.count == 19)
            
            return Data(bytes: UnsafePointer<UInt8>(array), count: array.count)
        case .HummingbirdBit:
        //Set all: 0xCA LED1 Reserved R1 G1 B1 R2 G2 B2 SS1 SS2 SS3 SS4 LED2 LED3 Time us(MSB) Time us(LSB) Time ms(MSB) Time ms(LSB)
            guard let leds = leds, let trileds = trileds, let servos = servos, let buzzer = buzzer else {
                NSLog("Missing information in the hummingbird bit output state")
                return Data()
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
        case .Finch: 
            // 0xD0, B_R(0-255), B_G(0-255), B_B(0-255), T1_R(0-255), T1_G(0-255), T1_B(0-255), T2_R(0-255),
            // T2_R(0-255), T2_R(0-255), T3_R(0-255), T3_G(0-255), T3_B(0-255), T4_R(0-255), T4_G(0-255), T4_B(0-255),
            // Time_us_MSB, Time_us_LSB, Time_ms_MSB, Time_ms_LSB
            guard let trileds = trileds, let buzzer = buzzer else {
                NSLog("Missing information in the hummingbird bit output state")
                return Data()
            }
            
            let letter: UInt8 = 0xD0
        
            let buzzerArray = buzzer.array()
        
            let array: [UInt8] = [letter,
                    trileds[0].tuple.0, trileds[0].tuple.1, trileds[0].tuple.2,
                    trileds[1].tuple.0, trileds[1].tuple.1, trileds[1].tuple.2,
                    trileds[2].tuple.0, trileds[2].tuple.1, trileds[2].tuple.2,
                    trileds[3].tuple.0, trileds[3].tuple.1, trileds[3].tuple.2,
                    trileds[4].tuple.0, trileds[4].tuple.1, trileds[4].tuple.2,
                    buzzerArray[0], buzzerArray[1], buzzerArray[2], buzzerArray[3]]
        
            assert(array.count == 20)
            //NSLog("Set all \(array)")
            return Data(bytes: UnsafePointer<UInt8>(array), count: array.count)

        case .MicroBit:
        /** Micro:bit I/O :
         * 0x90, FrequencyMSB, FrequencyLSB, Time MSB, Mode, Pad0_value, Pad1_value, Pad2_value
         * Frequency is valid for only pin 0
         *
         * Mode 8 bits:
         * FU, FU, P0_Mode_MSbit, P0_Mode_LSbit, P1_Mode_MSbit, P1_Mode_MSbit, P2_Mode_MSbit, P2_Mode_LSbit
         */
            guard let pins = pins, let buzzer = buzzer, let mode = mode, let modeByte = bitsToByte(mode) else {
                NSLog("Missing information in the micro:bit output state")
                return Data()
            }
            let letter: UInt8 = 0x90
            let buzzerArray = buzzer.array()
            
            var array: [UInt8]
            if mode[2] == 1 {
                array = [letter, buzzerArray[0], buzzerArray[1], buzzerArray[2], modeByte, buzzerArray[3], pins[1], pins[2]]
            } else {
                array = [letter, 0, 0, 0, modeByte, pins[0], pins[1], pins[2]]
            }
            
            //NSLog("micro:bit set all \(array)")
            return Data(bytes: UnsafePointer<UInt8>(array), count: array.count)
        }
    }
    
    //Set anything that will not fit into this robot's setAll command
    /*
    func setExtrasCommand() -> Data? {
        switch robotType {
        case .Hummingbird, .Flutter: return nil
        case .HummingbirdBit, .MicroBit: return robotType.ledArrayCommand(self.ledArray)
        case .Finch:
            return nil
        }
    }*/
    
    static func ==(lhs: BBTRobotOutputState, rhs: BBTRobotOutputState) -> Bool {
        return (lhs.trileds == rhs.trileds) && (lhs.servos == rhs.servos) &&
            (lhs.leds == rhs.leds) && (lhs.motors == rhs.motors) &&
            (lhs.vibrators == rhs.vibrators) && (lhs.buzzer == rhs.buzzer) &&
            (lhs.ledArray == rhs.ledArray) && (lhs.pins == rhs.pins) &&
            (lhs.mode == rhs.mode)
    }
}

