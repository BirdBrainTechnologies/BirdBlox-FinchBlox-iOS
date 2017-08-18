//
//  SharedUtilities.swift
//  BirdBlox
//
//  Created by birdbrain on 4/3/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//
// This file provides utility functions for converting and bounding data
//

import Foundation

/**
    Takes an int and returns the unicode value for the int as a string
 */
public func getUnicode(_ num: UInt8) -> UInt8{
    let scalars = String(num).unicodeScalars
    return UInt8(scalars[scalars.startIndex].value)
}

/**
    Gets the unicode value for a character
 */
public func getUnicode(_ char: Character) -> UInt8{
    let scalars = String(char).unicodeScalars
    return UInt8(scalars[scalars.startIndex].value)
}

/**
    Takes a string and splits it into a byte array with end of line characters
    at the end
 */
public func StringToCommand(_ phrase: String) -> Data{
    var result: [UInt8] = []
    for character in phrase.utf8{
        result.append(character)
    }
    result.append(0x0D)
    result.append(0x0A)
    return Data(bytes: UnsafePointer<UInt8>(result), count: result.count)
}

/**
    Takes a string and splits it into a byte array
 */
public func StringToCommandNoEOL(_ phrase: String) -> Data{
    var result: [UInt8] = []
    for character in phrase.utf8{
        result.append(character)
    }
    return Data(bytes: UnsafePointer<UInt8>(result), count: result.count)
}

/**
    Bounds a UInt8 with a min and max value
 */
public func bound(_ value: UInt8, min: UInt8, max: UInt8) -> UInt8 {
    var new_value = value < min ? min : value
    new_value = value > max ? max : value
    return new_value
}

/**
    Bounds an Int with a min and max value
 */
public func bound(_ value: Int, min: Int, max: Int) -> Int {
    var new_value = value < min ? min : value
    new_value = value > max ? max : value
    return new_value
}

/**
    Converts an int to a UInt8 by bounding it to the range of a UInt8
 */
public func toUInt8(_ value: Int) -> UInt8 {
    var new_value = value < 0 ? 0 : value
    new_value = value > 255 ? 255 : value
    return UInt8(new_value)
}


//data Conversions

/**
    Converts a raw value from a robot into a temperature
 */
public func rawToTemp(_ raw_val: UInt8) -> Int{
    print("hi")
    let temp: Int = Int(floor(((Double(raw_val) - 127.0)/2.4 + 25) * 100 / 100));
    print("ho")
    return temp
}

/**
 Converts a raw value from a robot into a distance
 */
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

/**
 Converts a raw value from a robot into a voltage
 */
public func rawToVoltage(_ raw_val: UInt8) -> Int{
    return Int(floor((100.0 * Double(raw_val) / 51.0) / 100))
}

/**
 Converts a raw value from a robot into a sound value
 */
public func rawToSound(_ raw_val: UInt8) -> Int{
    return Int(raw_val)
}

/**
 Converts a raw value from a robot into a percentage
 */
public func rawToPercent(_ raw_val: UInt8) -> Int{
    return Int(floor(Double(raw_val)/2.55))
}

/**
 Converts a percentage value into a raw value from a robot
 */
public func percentToRaw(_ percent_val: UInt8) -> UInt8{
    return toUInt8(Int(floor(Double(percent_val) * 2.55)))
}

/**
  Converts the boards GAP name to a kid friendly name for the UI to display
  Returns nil if the input name is malformed
  */
public func BBTkidNameFromMacSuffix(_ deviceName: String) -> String? {
//	let deviceName = deviceNameS.utf8
	
	//The name should be seven characters, with the first two identifying the type of device
	//The last five characters should be from the device's MAC address
	
	if deviceName.utf8.count == 7,
		let namesPath = Bundle.main.path(forResource: "BluetoothDeviceNames", ofType: "plist"),
		let namesDict = NSDictionary(contentsOfFile: namesPath),
		let mac = Int(deviceName[deviceName.index(deviceName.startIndex,
		                                          offsetBy: 2)..<deviceName.endIndex], radix: 16)  {
		
		 // grab bits from the MAC address (6 bits, 6 bits, 8 bits => last, middle, first)
		 // (5 digis of mac address is 20 bits) llllllmmmmmmffffffff
		 
		let macNumber = mac
		let offset = (macNumber & 0xFF) % 16
		let firstIndex = (macNumber & 0xFF) + offset
		let middleIndex = ((macNumber >> 8) & 0b111111) + offset
		let lastIndex = ((macNumber >> (8+6)) & 0b111111) + offset
		
		let namesDict = namesDict as! Dictionary<String, Array<String>>
		let preName = namesDict["first_names"]![firstIndex] + " " +
			namesDict["middle_names"]![middleIndex]
		let name = preName + " " + namesDict["last_names"]![lastIndex]
		
		print("\(deviceName) \(firstIndex), \(middleIndex), \(lastIndex)")
		
		return name
		
	}
	
	NSLog("Unable to parse GAP Name \"\(deviceName)\"")
	return nil
}

func BBTgetDeviceNameForGAPName(_ gap: String) -> String {
	if let kidName = BBTkidNameFromMacSuffix(gap) {
		return kidName
	}
	
	//TODO: If the GAP name is the default hummingbird name, then grab the MAC address,
	//set the GAP name to "HB\(last 5 of MAC)", and use that to generate a kid name
	
	//Enter command mode with +++
	//Get MAC address with AT+BLEGETADDR
	//Set name with AT+GAPDEVNAME=BLEFriend
	//Reset device with ATZ
	
	return gap
}


/**
	Converts an array of queries (such as the one we get from swifter) into a dictionary with
	the parameters as keys and values as values.
	There are so few parameters that a parallel version is not worth it.
  */
public func BBTSequentialQueryArrayToDict
(_ queryArray: Array<(String, String)>) -> Dictionary<String, String> {
	var dict = [String: String]()
	
	for (k, v) in queryArray {
		dict[k] = v
	}
	
	return dict
}


struct FixedLengthArray<T: Equatable>: Equatable {
	private var array: Array<T>
	let length: Int
	
	init(_ from: Array<T>) {
		array = from
		length = from.count
	}
	
	init(length: UInt, repeating: T) {
		let arr = Array<T>(repeating: repeating, count: Int(length))
		self.init(arr)
	}
	
	subscript (index: Int) -> T {
		get {
			return self.array[index]
		}
		
		set(value) {
			self.array[index] = value
		}
	}
	
	static func ==(inLeft: FixedLengthArray, inRight: FixedLengthArray) -> Bool {
		return (inLeft.length == inRight.length) && (inLeft.array == inRight.array)
	}
}

