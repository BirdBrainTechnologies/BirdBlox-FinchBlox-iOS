//
//  HummingbirdUtilities.swift
//  BirdBlox
//
//  Created by birdbrain on 4/3/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation

public func getLEDCommand(_ port: UInt8, intensity: UInt8) -> Data{
    let real_port: UInt8 = getUnicode(port-1)
    let letter: UInt8 = 0x4C
    let bounded_intensity = bound(intensity, min: 0, max: 100)
    let real_intensity = UInt8(floor(Double(bounded_intensity)*2.55))
    return Data(bytes: UnsafePointer<UInt8>([letter, real_port, real_intensity] as [UInt8]), count: 3)
}

public func getTriLEDCommand(_ port: UInt8, red_val: UInt8, green_val: UInt8, blue_val: UInt8) ->Data{
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

//speed should be from -100 to 100
public func getMotorCommand(_ port: UInt8, speed: Int) -> Data{
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

public func getVibrationCommand(_ port: UInt8, intensity: UInt8) -> Data{
    let real_port: UInt8 = getUnicode(port-1)
    let letter: UInt8 = 0x56
    let bounded_intensity = bound(intensity, min: 0, max: 100)
    let real_intensity: UInt8 = UInt8(floor(Double(bounded_intensity)*2.55))
    return Data(bytes: UnsafePointer<UInt8>([letter, real_port, real_intensity] as [UInt8]), count: 3)
}

//angle should be from 0 to 180
public func getServoCommand(_ port: UInt8, angle: UInt8) -> Data{
    let real_port: UInt8 = getUnicode(port-1)
    let letter: UInt8 = 0x53
    let bounded_angle = bound(angle, min: 0, max: 180)
    let real_angle = UInt8(floor(Double(bounded_angle)*1.25))
    return Data(bytes: UnsafePointer<UInt8>([letter, real_port, real_angle] as [UInt8]), count: 3)
}

public func getSetAllCommand(tri: [[UInt8]], leds: [UInt8], servos: [UInt8], motors: [Int], vibs: [UInt8]) -> Data {
    let letter: UInt8 = 0x41
    var adjusted_motors: [UInt8] = [0,0]
    if motors[0] < 0 {
        adjusted_motors[0] = UInt8(motors[0] * -1 + 128)
    } else {
        adjusted_motors[0] = UInt8(motors[0])
    }
    if motors[1] < 0 {
        adjusted_motors[1] = UInt8(motors[1] * -1 + 128)
    } else {
        adjusted_motors[1] = UInt8(motors[1])
    }
    var array: [UInt8] = [letter] + tri[0] + tri[1]
    array = array + leds + servos + vibs + adjusted_motors
    return Data(bytes: UnsafePointer<UInt8>(array), count: 19)
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

