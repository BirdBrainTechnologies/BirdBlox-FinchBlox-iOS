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
        case .HummingbirdBit: return 29
        case .MicroBit: return 25
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
    
    //MARK: Strings
    var description: String {
        switch self {
        case .Hummingbird: return "Hummingbird"
        case .Flutter: return "Flutter"
        case .Finch: return "Finch"
        case .HummingbirdBit: return "HummingbirdBit"
        case .MicroBit: return "MicroBit"
        }
    }
    
    static func fromString(_ s: String) -> BBTRobotType? {
        //Usually should determine type from the first 2 letters of the
        //peripheral name.
        switch s.prefix(2) {
        case "HM": return .HummingbirdBit
        case "MB": return .HummingbirdBit
        case "FN": return .Finch
        case "HB": return .Hummingbird
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
    func command(_ commandName: String) -> Data {
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
        case .HummingbirdBit: return 13
        case .MicroBit: return 9
        }
    }
    
}
