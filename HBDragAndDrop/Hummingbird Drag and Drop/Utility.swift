//
//  Commands.swift
//  HummingbirdLibrary
//
//  Created by birdbrain on 5/29/15.
//  Copyright (c) 2015 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation

public func dbg_print(object: Any) {
    NSLog(object as! String)
}

public func getUnicode(num: UInt8) -> UInt8{
    let scalars = String(num).unicodeScalars
    return UInt8(scalars[scalars.startIndex].value)
}
public func StringToCommand(phrase: String) -> NSData{
    var result: [UInt8] = []
    for character in phrase.utf8{
        result.append(character)
    }
    result.append(0x0D)
    result.append(0x0A)
    return NSData(bytes: result, length: result.count)
}
public func StringToCommandNoEOL(phrase: String) -> NSData{
    var result: [UInt8] = []
    for character in phrase.utf8{
        result.append(character)
    }
    return NSData(bytes: result, length: result.count)
}
public func getLEDCommand(port: UInt8, intensity: UInt8) -> NSData{
    let realPort: UInt8 = getUnicode(port-1)
    let letter: UInt8 = 0x4C
    let realIntensity = UInt8(floor(Double(intensity)*2.55))
    return NSData(bytes: [letter, realPort, realIntensity] as [UInt8], length: 3)
}

public func getTriLEDCommand(port: UInt8, redVal: UInt8, greenVal: UInt8, blueVal: UInt8) ->NSData{
    let realPort: UInt8 = getUnicode(port-1)
    let letter: UInt8 = 0x4F
    let realRed = UInt8(floor(Double(redVal)*2.55))
    let realGreen = UInt8(floor(Double(greenVal)*2.55))
    let realBlue = UInt8(floor(Double(blueVal)*2.55))
    return NSData(bytes: [letter, realPort, realRed, realGreen, realBlue] as [UInt8], length: 5)
}

//speed should be from -100 to 100
public func getMotorCommand(port: UInt8, speed: Int) -> NSData{
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
    return NSData(bytes: [letter, realPort, realDirection, realSpeed] as [UInt8], length: 4)
}

public func getVibrationCommand(port: UInt8, intensity: UInt8) -> NSData{
    let realPort: UInt8 = getUnicode(port-1)
    let letter: UInt8 = 0x56
    let realIntensity: UInt8 = UInt8(floor(Double(intensity)*2.55))
    return NSData(bytes: [letter, realPort, realIntensity] as [UInt8], length: 3)
}

//angle should be from 0 to 180
public func getServoCommand(port: UInt8, angle: UInt8) -> NSData{
    let realPort: UInt8 = getUnicode(port-1)
    let letter: UInt8 = 0x53
    let realAngle = UInt8(floor(Double(angle)*1.25))
    return NSData(bytes: [letter, realPort, realAngle] as [UInt8], length: 3)
}

public func getResetCommand() -> NSData{
    let letter: UInt8 = 0x52
    return NSData(bytes: [letter] as [UInt8], length: 1)
}

public func getTurnOffCommand() -> NSData{
    let letter: UInt8 = 0x58
    return NSData(bytes: [letter] as [UInt8], length: 1)
}

public func getZCommand() -> NSData{
    let letter: UInt8 = 0x7A
    return NSData(bytes: [letter] as [UInt8], length: 1)
}

public func getPollSensorsCommand() -> NSData{
    let letter: UInt8 = 0x47
    let num: UInt8 = getUnicode(UInt8(3))
    return NSData(bytes: [letter,num] as [UInt8], length: 2)
}

public func getPollStartCommand() -> NSData{
    let letter: UInt8 = 0x47
    let num: UInt8 = getUnicode(UInt8(5))
    return NSData(bytes: [letter,num] as [UInt8], length: 2)
}
public func getPollStopCommand() -> NSData{
    let letter: UInt8 = 0x47
    let num: UInt8 = getUnicode(UInt8(6))
    return NSData(bytes: [letter,num] as [UInt8], length: 2)
}

//data Conversions
public func rawToTemp(rawVal: UInt8) -> Int{
    let temp: Int = Int(floor(((Double(rawVal) - 127.0)/2.4 + 25) * 100 / 100));
    return temp
}

public func rawToDistance(rawVal: UInt8) -> Int{
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

public func rawToVoltage(rawVal: UInt8) -> Int{
    return Int(floor((100.0 * Double(rawVal) / 51.0) / 100))
}

public func rawToSound(rawVal: UInt8) -> Int{
    return Int(rawVal)
}

public func rawto100scale(rawVal: UInt8) -> Int{
    return Int(floor(Double(rawVal)/2.55))
}

public func rawToRotary(rawVal: UInt8) -> Int{
    return rawto100scale(rawVal)
}

public func rawToLight(rawVal: UInt8) -> Int{
    return rawto100scale(rawVal)
}
