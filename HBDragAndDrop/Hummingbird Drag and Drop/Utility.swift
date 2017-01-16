//
//  Commands.swift
//  HummingbirdLibrary
//
//  Created by birdbrain on 5/29/15.
//  Copyright (c) 2015 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation

public func dbg_print(_ object: Any) {
    NSLog(object as! String)
}

public func getUnicode(_ num: UInt8) -> UInt8{
    let scalars = String(num).unicodeScalars
    return UInt8(scalars[scalars.startIndex].value)
}
public func StringToCommand(_ phrase: String) -> Data{
    var result: [UInt8] = []
    for character in phrase.utf8{
        result.append(character)
    }
    result.append(0x0D)
    result.append(0x0A)
    return Data(bytes: UnsafePointer<UInt8>(result), count: result.count)
}
public func StringToCommandNoEOL(_ phrase: String) -> Data{
    var result: [UInt8] = []
    for character in phrase.utf8{
        result.append(character)
    }
    return Data(bytes: UnsafePointer<UInt8>(result), count: result.count)
}
public func getLEDCommand(_ port: UInt8, intensity: UInt8) -> Data{
    let realPort: UInt8 = getUnicode(port-1)
    let letter: UInt8 = 0x4C
    let realIntensity = UInt8(floor(Double(intensity)*2.55))
    return Data(bytes: UnsafePointer<UInt8>([letter, realPort, realIntensity] as [UInt8]), count: 3)
}

public func getTriLEDCommand(_ port: UInt8, redVal: UInt8, greenVal: UInt8, blueVal: UInt8) ->Data{
    let realPort: UInt8 = getUnicode(port-1)
    let letter: UInt8 = 0x4F
    let realRed = UInt8(floor(Double(redVal)*2.55))
    let realGreen = UInt8(floor(Double(greenVal)*2.55))
    let realBlue = UInt8(floor(Double(blueVal)*2.55))
    return Data(bytes: UnsafePointer<UInt8>([letter, realPort, realRed, realGreen, realBlue] as [UInt8]), count: 5)
}

//speed should be from -100 to 100
public func getMotorCommand(_ port: UInt8, speed: Int) -> Data{
    var direction: UInt8 = 0
    let realPort: UInt8 = getUnicode(port-1)
    let letter: UInt8 = 0x4D
    var realSpeed: UInt8 = 0
    
    if (speed < 0){
        direction = 1
        realSpeed = UInt8(floor(Double(abs(speed))*2.55))
    }
    else{
        realSpeed = UInt8(floor(Double(speed)*2.55))
    }
    let realDirection: UInt8 = getUnicode(direction)
    return Data(bytes: UnsafePointer<UInt8>([letter, realPort, realDirection, realSpeed] as [UInt8]), count: 4)
}

public func getVibrationCommand(_ port: UInt8, intensity: UInt8) -> Data{
    let realPort: UInt8 = getUnicode(port-1)
    let letter: UInt8 = 0x56
    let realIntensity: UInt8 = UInt8(floor(Double(intensity)*2.55))
    return Data(bytes: UnsafePointer<UInt8>([letter, realPort, realIntensity] as [UInt8]), count: 3)
}

//angle should be from 0 to 180
public func getServoCommand(_ port: UInt8, angle: UInt8) -> Data{
    let realPort: UInt8 = getUnicode(port-1)
    let letter: UInt8 = 0x53
    let realAngle = UInt8(floor(Double(angle)*1.25))
    return Data(bytes: UnsafePointer<UInt8>([letter, realPort, realAngle] as [UInt8]), count: 3)
}

public func getResetCommand() -> Data{
    let letter: UInt8 = 0x52
    return Data(bytes: UnsafePointer<UInt8>([letter] as [UInt8]), count: 1)
}

public func getTurnOffCommand() -> Data{
    let letter: UInt8 = 0x58
    return Data(bytes: UnsafePointer<UInt8>([letter] as [UInt8]), count: 1)
}

public func getZCommand() -> Data{
    let letter: UInt8 = 0x7A
    return Data(bytes: UnsafePointer<UInt8>([letter] as [UInt8]), count: 1)
}

public func getPollSensorsCommand() -> Data{
    let letter: UInt8 = 0x47
    let num: UInt8 = getUnicode(UInt8(3))
    return Data(bytes: UnsafePointer<UInt8>([letter,num] as [UInt8]), count: 2)
}

public func getPollStartCommand() -> Data{
    let letter: UInt8 = 0x47
    let num: UInt8 = getUnicode(UInt8(5))
    return Data(bytes: UnsafePointer<UInt8>([letter,num] as [UInt8]), count: 2)
}
public func getPollStopCommand() -> Data{
    let letter: UInt8 = 0x47
    let num: UInt8 = getUnicode(UInt8(6))
    return Data(bytes: UnsafePointer<UInt8>([letter,num] as [UInt8]), count: 2)
}

//data Conversions
public func rawToTemp(_ rawVal: UInt8) -> Int{
    let temp: Int = Int(floor(((Double(rawVal) - 127.0)/2.4 + 25) * 100 / 100));
    return temp
}

public func rawToDistance(_ rawVal: UInt8) -> Int{
    var reading: Double = Double(rawVal) * 4.0
    if(reading < 130){
        return 100
    }
    else{//formula based on mathematical regression
        reading = reading - 120.0
        if(reading > 680.0){
            return 5
        }
        else{
            let sensor_val_square = reading * reading
            let distance: Double = sensor_val_square * sensor_val_square * reading * -0.000000000004789 + sensor_val_square * sensor_val_square * 0.000000010057143 - sensor_val_square * reading * 0.000008279033021 + sensor_val_square * 0.003416264518201 - reading * 0.756893112198934 + 90.707167605683000;
            return Int(distance)
        }
    }
}

public func rawToVoltage(_ rawVal: UInt8) -> Int{
    return Int(floor((100.0 * Double(rawVal) / 51.0) / 100))
}

public func rawToSound(_ rawVal: UInt8) -> Int{
    return Int(rawVal)
}

public func rawto100scale(_ rawVal: UInt8) -> Int{
    return Int(floor(Double(rawVal)/2.55))
}

public func rawToRotary(_ rawVal: UInt8) -> Int{
    return rawto100scale(rawVal)
}

public func rawToLight(_ rawVal: UInt8) -> Int{
    return rawto100scale(rawVal)
}
