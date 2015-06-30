//
//  Commands.swift
//  HummingbirdLibrary
//
//  Created by birdbrain on 5/29/15.
//  Copyright (c) 2015 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
/**
    A debugging print statement
*/
public func dbg_print(object: Any) {
    //NSLog(object as! String)
}
/**
    Takes a number and turns it into unicode

    :param: num UInt8 the number to be converted

    :returns: UInt8 the unicode for the input number
*/
public func getUnicode(num: UInt8) -> UInt8{
    let scalars = String(num).unicodeScalars
    return UInt8(scalars[scalars.startIndex].value)
}
/**
    Takes a string and converts it to NSData in the form of a valid command to the BLE module

    :param: phrase String the phrase to be converted to a command

    :returns: NSData the command based on the input string
*/
public func StringToCommand(phrase: String) -> NSData{
    var result: [UInt8] = []
    for character in phrase.utf8{
        result.append(character)
    }
    result.append(0x0D)
    result.append(0x0A)
    return NSData(bytes: result, length: result.count)
}
/**
    The same as StringToCommand but doesn't add an end of line character at the end

    :param: phrase String the phrase to be converted to a command

    :returns: NSData the command based on the input string
*/
public func StringToCommandNoEOL(phrase: String) -> NSData{
    var result: [UInt8] = []
    for character in phrase.utf8{
        result.append(character)
    }
    return NSData(bytes: result, length: result.count)
}
/**
    Gets the command to set the LED

    :param: port UInt8 The port of the LED, should be from 1-4

    :param: intensity UInt8 The intensity to set the LED to, should be from 0-100

    :returns: NSData the command to set the LED
*/
public func getLEDCommand(port: UInt8, intensity: UInt8) -> NSData{
    let realPort: UInt8 = getUnicode(port-1)
    let letter: UInt8 = 0x4C
    let realIntensity = UInt8(floor(Double(intensity)*2.55))
    return NSData(bytes: [letter, realPort, realIntensity] as [UInt8], length: 3)
}
/**
    Gets the command to set the Tri-LED

    :param: port UInt8 The port of the LED, should be from 1-2

    :param: red UInt8 The intensity of the red component of the LED, should be from 0-100

    :param: green UInt8 The intensity of the green component of the LED, should be from 0-100

    :param: blue UInt8 The intensity of the blue component of the LED, should be from 0-100

    :returns: NSData the command to set the tri-LED

*/
public func getTriLEDCommand(port: UInt8, redVal: UInt8, greenVal: UInt8, blueVal: UInt8) ->NSData{
    let realPort: UInt8 = getUnicode(port-1)
    let letter: UInt8 = 0x4F
    let realRed = UInt8(floor(Double(redVal)*2.55))
    let realGreen = UInt8(floor(Double(greenVal)*2.55))
    let realBlue = UInt8(floor(Double(blueVal)*2.55))
    return NSData(bytes: [letter, realPort, realRed, realGreen, realBlue] as [UInt8], length: 5)
}

/**
    Gets the command to set the motor

    :param: port UInt8 The port of the motor, should be from 1-2

    :param: speed Int The speed of the motor, should be from -100 to 100

    :returns: NSData the command to set the motor
*/
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
/**
    Gets the command to set the vibration

    :param: port UInt8 The port of the vibrator, should be from 1-2

    :param: intensity UInt8 The intensity to set the vibrator to, should be from 0-100

    :returns: NSData the command to set the vibrator
*/
public func getVibrationCommand(port: UInt8, intensity: UInt8) -> NSData{
    let realPort: UInt8 = getUnicode(port-1)
    let letter: UInt8 = 0x56
    let realIntensity: UInt8 = UInt8(floor(Double(intensity)*2.55))
    return NSData(bytes: [letter, realPort, realIntensity] as [UInt8], length: 3)
}

/**
    Gets the command to set the servo

    :param: port UInt8 The port of the servo, should be from 1-4

    :param: angle UInt8 The angle to turn the servo too, should be from 0-180
    
    :returns: NSData the command to set the servo
*/
public func getServoCommand(port: UInt8, angle: UInt8) -> NSData{
    let realPort: UInt8 = getUnicode(port-1)
    let letter: UInt8 = 0x53
    let realAngle = UInt8(floor(Double(angle)*1.25))
    return NSData(bytes: [letter, realPort, realAngle] as [UInt8], length: 3)
}
/**
    Gets the hummingbird reset command

    :returns: NSData the command to reset the hummingbird
*/
public func getResetCommand() -> NSData{
    let letter: UInt8 = 0x52
    return NSData(bytes: [letter] as [UInt8], length: 1)
}
/**
    Gets the hummingbird shutdown command

    :returns: NSData the command to turn off the hummingbird
*/
public func getTurnOffCommand() -> NSData{
    let letter: UInt8 = 0x58
    return NSData(bytes: [letter] as [UInt8], length: 1)
}
/**
    Gets the Z command. This shouldn't be used as this library expects that the only message the hummingbird sends to the iOS device is sensor information. If this command were to be sent, the response would most likely be ignored

    :returns: NSData the command to send Z to the hummingbird
*/
public func getZCommand() -> NSData{
    let letter: UInt8 = 0x7A
    return NSData(bytes: [letter] as [UInt8], length: 1)
}
/**
    Gets the poll sensors command (the explicit request to get sensor information once)

    :returns: NSData the command to poll the sensors once
*/
public func getPollSensorsCommand() -> NSData{
    let letter: UInt8 = 0x47
    let num: UInt8 = getUnicode(UInt8(3))
    return NSData(bytes: [letter,num] as [UInt8], length: 2)
}
/**
    Gets the command to begin a constant poll

    :returns: NSData the command to continually poll the sensors
*/
public func getPollStartCommand() -> NSData{
    let letter: UInt8 = 0x47
    let num: UInt8 = getUnicode(UInt8(5))
    return NSData(bytes: [letter,num] as [UInt8], length: 2)
}
/**
    Gets the command to stop a constant poll

    :returns: NSData the command to stop continually polling the sensors
*/
public func getPollStopCommand() -> NSData{
    let letter: UInt8 = 0x47
    let num: UInt8 = getUnicode(UInt8(6))
    return NSData(bytes: [letter,num] as [UInt8], length: 2)
}

//data Conversions
/**
    Converts a raw sensor value to temperature

    :returns: Int temperature in Celcius
*/
public func rawToTemp(rawVal: UInt8) -> Int{
    let temp: Int = Int(floor(((Double(rawVal) - 127.0)/2.4 + 25) * 100 / 100));
    return temp
}
/**
    Converts a raw sensor value to distance

    :returns: Int distance in cm
*/
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
/**
    Converts a raw sensor value to voltage

    :returns: Int voltage
*/
public func rawToVoltage(rawVal: UInt8) -> Int{
    return Int(floor((100.0 * Double(rawVal) / 51.0) / 100))
}
/**
    Converts a raw sensor value to sound level

    :returns: Int sound level
*/
public func rawToSound(rawVal: UInt8) -> Int{
    return Int(rawVal)
}
/**
    Converts a raw sensor value to a 100 scale

    :returns: Int the adjusted value
*/
public func rawto100scale(rawVal: UInt8) -> Int{
    return Int(floor(Double(rawVal)/2.55))
}
/**
    Converts a raw sensor value to a rotary value

    :returns: Int the adjusted value
*/
public func rawToRotary(rawVal: UInt8) -> Int{
    return rawto100scale(rawVal)
}
/**
    Converts a raw sensor value to a light value

    :returns: Int the adjusted value
*/
public func rawToLight(rawVal: UInt8) -> Int{
    return rawto100scale(rawVal)
}
