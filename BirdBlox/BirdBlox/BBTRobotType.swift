//
//  BBTRobotType.swift
//  BirdBlox
//
//  Created by Kristina Lauwers on 5/2/18.
//  Copyright © 2018 Birdbrain Technologies LLC. All rights reserved.
//MB9680E MB9680E MB9680E

import Foundation
import CoreBluetooth

enum BBTRobotType {
    case Hummingbird, Flutter, Finch, HummingbirdBit, MicroBit
    
    //MARK: UUIDs
    //UUID for the BLE adapter
    var scanningUUID: CBUUID {
        switch self {
        case .Hummingbird, .Finch, .HummingbirdBit, .MicroBit: return CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
        case .Flutter: return CBUUID(string: "BC2F4CC6-AAEF-4351-9034-D66268E328F0")
        }
    }
    
    //UART Service UUID
    var SERVICE_UUID: CBUUID {
        switch self {
        case .Hummingbird, .Finch, .HummingbirdBit, .MicroBit:
            return CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
        case .Flutter: return CBUUID(string: "BC2F4CC6-AAEF-4351-9034-D66268E328F0")
        }
    }
    
    //sending
    var TX_UUID: CBUUID {
        switch self {
        case .Hummingbird, .Finch, .HummingbirdBit, .MicroBit:
            return CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
        case .Flutter: return CBUUID(string: "06D1E5E7-79AD-4A71-8FAA-373789F7D93C")
        }
    }
    
    //receiving
    var RX_UUID: CBUUID {
        switch self {
        case .Hummingbird, .Finch, .HummingbirdBit, .MicroBit:
            return CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
        case .Flutter: return CBUUID(string: "818AE306-9C5B-448D-B51A-7ADD6A5D314D")
        }
    }
    
    var RX_CONFIG_UUID: CBUUID {
        switch self {
        case .Hummingbird, .Finch, .HummingbirdBit, .MicroBit: return CBUUID(string: "00002902-0000-1000-8000-00805f9b34fb")
        case .Flutter: return CBUUID(string: "00002902-0000-1000-8000-00805f9b34fb")
        }
    }
    
    //MARK: Firmware
    var minimumFirmware: String {
        return "2.2a"
    }
    
    var latestFirmware: String {
        return "2.2b"
    }
    
    //MARK: Outputs
    var triledCount: UInt {
        switch self {
        case .Hummingbird: return 2
        case .Flutter: return 2
        case .Finch: return 1
        case .HummingbirdBit: return 2
        case .MicroBit: return 0
        }
    }
    var ledCount: UInt {
        switch self {
        case .Hummingbird: return 4
        case .Flutter: return 0
        case .Finch: return 0
        case .HummingbirdBit: return 3
        case .MicroBit: return 0
        }
    }
    var servoCount: UInt {
        switch self {
        case .Hummingbird: return 4
        case .Flutter: return 3
        case .Finch: return 0
        case .HummingbirdBit: return 4
        case .MicroBit: return 0
        }
    }
    var motorCount: UInt {
        switch self {
        case .Hummingbird: return 2
        case .Flutter: return 0
        case .Finch: return 2
        case .HummingbirdBit: return 0
        case .MicroBit: return 0
        }
    }
    var vibratorCount: UInt {
        switch self {
        case .Hummingbird: return 2
        case .Flutter: return 0
        case .Finch: return 0
        case .HummingbirdBit: return 0
        case .MicroBit: return 0
        }
    }
    var buzzerCount: UInt {
        switch self {
        case .Hummingbird: return 0
        case .Flutter: return 1
        case .Finch: return 1
        case .HummingbirdBit: return 1
        case .MicroBit: return 0
        }
    }
    var ledArrayCount: UInt {
        switch self {
        case .Hummingbird, .Flutter: return 0
        case .Finch, .HummingbirdBit, .MicroBit: return 1
        }
    }
    
    //MARK: Inputs
    var sensorPortCount: UInt {
        switch self {
        case .Hummingbird, .HummingbirdBit: return 4
        case .Finch, .Flutter, .MicroBit: return 0
        }
    }
    
    //MARK: Strings
    var description: String {
        switch self {
        case .Hummingbird: return "Duo"
        case .Flutter: return "Flutter"
        case .Finch: return "Finch"
        case .HummingbirdBit: return "Bit"
        case .MicroBit: return "micro:bit"
        }
    }
    
    static func fromString(_ s: String) -> BBTRobotType? {
        //Usually should determine type from the first 2 letters of the
        //peripheral name.
        switch s.prefix(2) {
        case "BB": return .HummingbirdBit
        case "MB": return .MicroBit
        case "FN": return .Finch
        case "HB", "HM": return .Hummingbird
        case "FL": return .Flutter
        default:
            switch s {
            case "hummingbird",
                 "Hummingbird":
                return .Hummingbird
            case "Flutter",
                 "flutter",
                 "fl":
                return .Flutter
            case "Finch",
                 "finch":
                return .Finch
            case "HummingbirdBit",
                 "hummingbirdbit":
                return .HummingbirdBit
            case "MicroBit",
                 "microbit":
                return .MicroBit
            default:
                return nil
            }
        }
    }
    
    //MARK: Sensor polling
    func sensorCommand(_ commandName: String) -> Data {
        var letter: UInt8 = 0
        var num: UInt8 = 0
        
        switch self {
        case .Hummingbird:
            letter = 0x47
            if commandName == "pollStart" {
                num = getUnicode(UInt8(5))
            } else { num = getUnicode(UInt8(6)) } //pollStop
        case .Flutter: ()
        case .Finch, .HummingbirdBit, .MicroBit:
            letter = 0x62
            if commandName == "pollStart" {
                print("poll start hummingbird bit")
                num = 0x67
            } else { num = 0x73 }//pollStop
        }
        return Data(bytes: UnsafePointer<UInt8>([letter,num] as [UInt8]), count: 2)
    }
    var sensorByteCount: Int {
        switch self {
        case .Hummingbird: return 4
        case .Flutter: return 1
        case .Finch: return 10
        case .HummingbirdBit: return 14
        case .MicroBit: return 14
        }
    }
    
    //MARK: output commands
    func ledCommand(_ port: UInt8, intensity: UInt8) -> Data? {
        let bounded_intensity = bound(intensity, min: 0, max: 100)
        let real_intensity = UInt8(floor(Double(bounded_intensity)*2.55))
        switch self {
        case .Hummingbird:
            let real_port: UInt8 = getUnicode(port-1)
            let letter: UInt8 = 0x4C
            return Data(bytes: UnsafePointer<UInt8>([letter, real_port, real_intensity] as [UInt8]), count: 3)
        case .HummingbirdBit:
            //TODO: Test this
            let letter: UInt8 = 0xC0 + port
            return Data(bytes: UnsafePointer<UInt8>([letter, real_intensity, 0xFF, 0xFF] as [UInt8]), count: 4)
        case .Finch, .Flutter, .MicroBit: return nil
        }
    }
    
    func triLEDCommand (_ port: UInt8, red_val: UInt8, green_val: UInt8, blue_val: UInt8) ->Data? {
        let bounded_red = bound(red_val, min: 0, max: 100)
        let real_red = UInt8(floor(Double(bounded_red)*2.55))
        let bounded_green = bound(green_val, min: 0, max: 100)
        let real_green = UInt8(floor(Double(bounded_green)*2.55))
        let bounded_blue = bound(blue_val, min: 0, max: 100)
        let real_blue = UInt8(floor(Double(bounded_blue)*2.55))
        switch self {
        case .Hummingbird:
            let real_port: UInt8 = getUnicode(port-1)
            let letter: UInt8 = 0x4F
            return Data(bytes: UnsafePointer<UInt8>([letter, real_port, real_red, real_green, real_blue] as [UInt8]), count: 5)
        case .HummingbirdBit:
        //TODO: Test this
            let letter: UInt8 = 0xC4 + port
            return Data(bytes: UnsafePointer<UInt8>([letter, real_red, real_green, real_blue] as [UInt8]), count: 4)
        case .Finch:
        //TODO: implement something here. Finch should have a triled.
            return nil
        case .Flutter:
            return nil
        case .MicroBit: return nil
            
        }
    }
    
    func motorCommand (_ port: UInt8, speed: Int) -> Data? {
        
        switch self {
        case .Hummingbird:
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
        case .Finch:
        //TODO: implement something here
            return nil
        case .Flutter, .HummingbirdBit, .MicroBit: return nil
        }
    }
    
    func vibrationCommand(_ port: UInt8, intensity: UInt8) -> Data? {
        switch self{
        case .Hummingbird:
            let real_port: UInt8 = getUnicode(port-1)
            let letter: UInt8 = 0x56
            let bounded_intensity = bound(intensity, min: 0, max: 100)
            let real_intensity: UInt8 = UInt8(floor(Double(bounded_intensity)*2.55))
            return Data(bytes: UnsafePointer<UInt8>([letter, real_port, real_intensity] as [UInt8]), count: 3)
        case .Flutter, .Finch, .HummingbirdBit, .MicroBit: return nil
        }
    }
    
    func servoCommand(_ port: UInt8, angle: UInt8) -> Data? {
        switch self{
        case .Hummingbird://TODO: fix this? scaled when message received
            let real_port: UInt8 = getUnicode(port-1)
            let letter: UInt8 = 0x53
            let bounded_angle = bound(angle, min: 0, max: 180)
            let real_angle = UInt8(floor(Double(bounded_angle)*1.25))
            return Data(bytes: UnsafePointer<UInt8>([letter, real_port, real_angle] as [UInt8]), count: 3)
        case .HummingbirdBit:
        //TODO: implement something here
            return nil
        case .Flutter:
            return nil
        case .Finch, .MicroBit: return nil
        }
    }
    
    func buzzerCommand(period: UInt16, dur: UInt16) -> Data? {
        switch self{
        case .Flutter, .Finch:
        //TODO:
            return nil
        case .HummingbirdBit: //TODO: test
            let letter: UInt8 = 0xCD
            let buzzer = BBTBuzzer(freq: 0, vol: 0, period: period, duration: dur)
            let buzzerArray = buzzer.array()
            return Data(bytes: UnsafePointer<UInt8>([letter, buzzerArray[0], buzzerArray[1], buzzerArray[2], buzzerArray[3]] as [UInt8]), count: 5)
        case .Hummingbird, .MicroBit: return nil
        }
    }
    
    func ledArrayCommand(_ status: String) -> Data? {
        switch self {
        case .Hummingbird, .Flutter: return nil
        case .HummingbirdBit, .Finch, .MicroBit:
            let letter: UInt8 = 0xCC
            let ledStatusChars = Array(status)
            
            switch ledStatusChars[0] {
            case "S": //Set a symbol
                let symbol: UInt8 = 0x80
                
                var led8to1String = ""
                for i in 1 ..< 9 {
                    led8to1String = String(ledStatusChars[i]) + led8to1String
                }
        
                var led16to9String = ""
                for i in 9 ..< 17 {
                    led16to9String = String(ledStatusChars[i]) + led16to9String
                }
                
                var led24to17String = ""
                for i in 17 ..< 25 {
                    led24to17String = String(ledStatusChars[i]) + led24to17String
                }
                
                guard let leds8to1 = UInt8(led8to1String, radix: 2),
                    let led16to9 = UInt8(led16to9String, radix: 2),
                    let led24to17 = UInt8(led24to17String, radix: 2),
                    let led25 = UInt8(String(ledStatusChars[25])) else {
                        fatalError()
                }
                
                NSLog("Symbol command \([letter, symbol, led25, led24to17, led16to9, leds8to1])")
                return Data(bytes: UnsafePointer<UInt8>([letter, symbol, led25, led24to17, led16to9, leds8to1] as [UInt8]), count: 6)
                
            case "F": //flash a string
                let length = ledStatusChars.count - 1
                let flash = UInt8(64 + length)
                var commandArray = [letter, flash]
                for i in 1 ... length {
                    commandArray.append(getUnicode(ledStatusChars[i]))
                }
                
                NSLog("Flash command \(commandArray)")
                return Data(bytes: UnsafePointer<UInt8>(commandArray), count: length + 2)
            default: return nil
            }
        }
    }
    
    func clearLedArrayCommand() -> Data? {
        //To stop flashing or clearing the screen use
        //0xCC 0x00 0xFF 0xFF 0xFF
        switch self {
        case .Finch, .HummingbirdBit, .MicroBit:
            return Data(bytes: UnsafePointer<UInt8>([0xCC, 0x00, 0xFF, 0xFF, 0xFF] as [UInt8]), count: 5)
        case .Flutter, .Hummingbird: return nil
        }
    }
    
    func turnOffCommand() -> Data{
        switch self {
        case .Hummingbird, .Flutter:
            let letter: UInt8 = 0x58
            return Data(bytes: UnsafePointer<UInt8>([letter] as [UInt8]), count: 1)
        case .HummingbirdBit:
            let letter: UInt8 = 0xCB
            //this command only turns off servos and leds
            return Data(bytes: UnsafePointer<UInt8>([letter, 0xFF, 0xFF, 0xFF] as [UInt8]), count: 4)
        case .Finch:
            //TODO:
            return Data()
        case .MicroBit:
            //TODO:
            return Data()
        }
    }
    
    //MARK: Other commands
    func calibrateMagnetometerCommand() -> Data? {
        //Calibrate Magnetometer: 0xCE 0xFF 0xFF 0xFF
        switch self {
        case .HummingbirdBit, .MicroBit, .Finch:
            return Data(bytes: UnsafePointer<UInt8>([0xCE, 0xFF, 0xFF, 0xFF] as [UInt8]), count: 4)
        case .Flutter, .Hummingbird: return nil
        }
    }
    
    func hardwareFirmwareVersionCommand() -> Data? {
        switch self {
        case .Hummingbird:
            return "G4".data(using: .utf8)!
        case .HummingbirdBit, .MicroBit:
            return Data(bytes: UnsafePointer<UInt8>([0xCF, 0xFF, 0xFF, 0xFF] as [UInt8]), count: 4)
        case .Flutter, .Finch: return nil
        }
    }
}
