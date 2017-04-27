//
//  SharedUtilities.swift
//  BirdBlox
//
//  Created by birdbrain on 4/3/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation


public func getUnicode(_ num: UInt8) -> UInt8{
    let scalars = String(num).unicodeScalars
    return UInt8(scalars[scalars.startIndex].value)
}

public func getUnicode(_ char: Character) -> UInt8{
    let scalars = String(char).unicodeScalars
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

public func bound(_ value: UInt8, min: UInt8, max: UInt8) -> UInt8 {
    var new_value = value < min ? min : value
    new_value = value > max ? max : value
    return new_value
}

public func bound(_ value: Int, min: Int, max: Int) -> Int {
    var new_value = value < min ? min : value
    new_value = value > max ? max : value
    return new_value
}

public func toUInt8(_ value: Int) -> UInt8 {
    var new_value = value < 0 ? 0 : value
    new_value = value > 255 ? 255 : value
    return UInt8(new_value)
}


//data Conversions
public func rawToTemp(_ raw_val: UInt8) -> Int{
    let temp: Int = Int(floor(((Double(raw_val) - 127.0)/2.4 + 25) * 100 / 100));
    return temp
}

public func rawToDistance(_ raw_val: UInt8) -> Int{
    var reading: Double = Double(raw_val) * 4.0
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

public func rawToVoltage(_ raw_val: UInt8) -> Int{
    return Int(floor((100.0 * Double(raw_val) / 51.0) / 100))
}

public func rawToSound(_ raw_val: UInt8) -> Int{
    return Int(raw_val)
}

public func rawToPercent(_ raw_val: UInt8) -> Int{
    return Int(floor(Double(raw_val)/2.55))
}

public func rawToRotary(_ raw_val: UInt8) -> Int{
    return rawToPercent(raw_val)
}

public func rawToLight(_ raw_val: UInt8) -> Int{
    return rawToPercent(raw_val)
}

public func percentToRaw(_ percent_val: UInt8) -> Int{
    return Int(floor(Double(percent_val) * 2.55))
}
