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
import GLKit

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
    var val = scalars[scalars.startIndex].value
    if val > 255 {
        NSLog("Unicode for character \(char) not supported.")
        val = 254
    }
    return UInt8(val)
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

/**
    Find the mode (most frequent value) of an NSNumber array
    Failure returns 0
 */
public func mode(_ array: [NSNumber]) -> NSNumber {

    var counts = [NSNumber: Int]()
        
    array.forEach { counts[$0] = (counts[$0] ?? 0) + 1 }
        
    if let (value, _) = counts.max(by: {$0.1 < $1.1}) {
        //return (value, count)
        return value
    }
    return 0  //TODO: ?
}


//MARK: data Conversions

/**
 * Convert a byte of data into an array of bits
 */
func byteToBits(_ byte: UInt8) -> [UInt8] {
    var byte = byte
    var bits = [UInt8](repeating: 0, count: 8)
    for i in 0..<8 {
        let currentBit = byte & 0x01
        if currentBit != 0 {
            bits[i] = 1
        }
        
        byte >>= 1
    }
    
    return bits
}

/**
 * Convert an array of bits into a byte of data
 */
func bitsToByte(_ bits: [UInt8]) -> UInt8? {
    var string = ""
    for bit in bits {
        string += String(bit)
    }
    return UInt8(string, radix: 2) ?? nil
}

/**
    Converts a raw value from a robot into a temperature
 */
public func rawToTemp(_ raw_val: UInt8) -> Int{
    //print("hi")
    let temp: Int = Int(floor(((Double(raw_val) - 127.0)/2.4 + 25) * 100 / 100));
    //print("ho")
    return temp
}

/**
 * Converts a raw value from a robot into a distance
 * For use only with Hummingbird Duo distance sensors
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
public func rawToVoltage(_ raw_val: UInt8) -> Double {
    return Double(raw_val) * 0.0406
    //return Int(floor((100.0 * Double(raw_val) / 51.0) / 100))
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
 * Convert raw value into a scaled magnetometer value
 */
public func rawToMagnetometer(_ msb: UInt8, _ lsb: UInt8) -> Int {
    let scaledVal = rawToRawMag(msb, lsb) * 0.1 //scaling to put in units of uT
    return Int(scaledVal.rounded())
}
public func rawToRawMag(_ msb: UInt8, _ lsb: UInt8) -> Double {
    let uIntVal = (UInt16(msb) << 8) | UInt16(lsb)
    let intVal = Int16(bitPattern: uIntVal)
    return Double(intVal)
}

/**
 * Convert raw magnetometer value to magnetometer value in the finch reference frame
 */
public func rawToFinchMagnetometer(_ rawMag: [UInt8]) -> [Double] {
    let x = Double(Int8(bitPattern: rawMag[0]))
    let y = Double(Int8(bitPattern: rawMag[1]))
    let z = Double(Int8(bitPattern: rawMag[2]))
    
    let finchX = x
    let finchY = y * __cospi(40/180) + z * __sinpi(40/180)
    let finchZ = z * __cospi(40/180) - y * __sinpi(40/180)
    
    print("rawToFinchMagnetometer \(rawMag) \([x, y, z]) \([finchX, finchY, finchZ])")
    
    return [finchX, finchY, finchZ]
}

/**
 * Convert raw value into a scaled accelerometer value
 */
public func rawToAccelerometer(_ raw_val: UInt8) -> Double {
    return rawToAccelerometer(Double(Int8(bitPattern: raw_val)))
    //let intVal = Int8(bitPattern: raw_val) //convert to 2's complement signed int
    //let scaledVal = Double(intVal) * 196/1280 //scaling from bambi
    //return scaledVal
}
public func rawToAccelerometer(_ raw_val: Double) -> Double {
    return raw_val * 196/1280 //scaling from bambi
}

/**
 * Convert raw accelerometer values to raw accelerometer values in finch reference frame.
 * Must still use rawToAccelerometer to scale.
 */
public func rawToRawFinchAccelerometer(_ rawAcc: [UInt8]) -> [Double] {
    let x = Double(Int8(bitPattern: rawAcc[0]))
    let y = Double(Int8(bitPattern: rawAcc[1]))
    let z = Double(Int8(bitPattern: rawAcc[2]))
    
    let finchX = x
    let finchY = y * __cospi(40/180) - z * __sinpi(40/180)
    let finchZ = y * __sinpi(40/180) + z * __cospi(40/180)
    
    return [finchX, finchY, finchZ]
}

/**
 * Convert raw sensor values into a compass value
 */
public func rawToCompass(rawAcc: [UInt8], rawMag: [UInt8]) -> Int? {
    let acc = [Double(Int8(bitPattern: rawAcc[0])), Double(Int8(bitPattern: rawAcc[1])), Double(Int8(bitPattern: rawAcc[2]))]
    
    var mag:[Double] = []
    if rawMag.count == 3 { //values have already been converted to uT
        mag = [Double(Int8(bitPattern: rawMag[0])) * 10, Double(Int8(bitPattern: rawMag[1])) * 10, Double(Int8(bitPattern: rawMag[2])) * 10]
    } else {
        mag = [rawToRawMag(rawMag[0], rawMag[1]), rawToRawMag(rawMag[2], rawMag[3]), rawToRawMag(rawMag[4], rawMag[5])]
    }
    
    return DoubleToCompass(acc: acc, mag: mag)
    
    /*
    //Compass value is undefined in the case of 0 z direction acceleration
    if rawAcc[2] == 0 {
        return nil
    }
    
    var mx, my, mz:Double
    if rawMag.count == 3 { //values have already been converted to uT
        mx = Double(Int8(bitPattern: rawMag[0])) * 10
        my = Double(Int8(bitPattern: rawMag[1])) * 10
        mz = Double(Int8(bitPattern: rawMag[2])) * 10
    } else {
        mx = rawToRawMag(rawMag[0], rawMag[1])
        my = rawToRawMag(rawMag[2], rawMag[3])
        mz = rawToRawMag(rawMag[4], rawMag[5])
    }
    
    let ax = Double(Int8(bitPattern: rawAcc[0]))
    let ay = Double(Int8(bitPattern: rawAcc[1]))
    let az = Double(Int8(bitPattern: rawAcc[2]))
    
    let phi = atan(-ay/az)
    let theta = atan( ax / (ay*sin(phi) + az*cos(phi)) )
    
    let xP = mx
    let yP = my * cos(phi) - mz * sin(phi)
    let zP = my * sin(phi) + mz * cos(phi)
    
    let xPP = xP * cos(theta) + zP * sin(theta)
    let yPP = yP
    
    let angle = 180 + GLKMathRadiansToDegrees(Float(atan2(xPP, yPP)))
    let roundedAngle = Int(angle.rounded())
    
    return roundedAngle*/
}

public func DoubleToCompass(acc: [Double], mag: [Double]) -> Int? {
    //Compass value is undefined in the case of 0 z direction acceleration
    if acc[2] == 0 {
        return nil
    }
    
    let ax = acc[0]
    let ay = acc[1]
    let az = acc[2]
    
    let mx = mag[0]
    let my = mag[1]
    let mz = mag[2]
    
    let phi = atan(-ay/az)
    let theta = atan( ax / (ay*sin(phi) + az*cos(phi)) )
    
    let xP = mx
    let yP = my * cos(phi) - mz * sin(phi)
    let zP = my * sin(phi) + mz * cos(phi)
    
    let xPP = xP * cos(theta) + zP * sin(theta)
    let yPP = yP
    
    let angle = 180 + GLKMathRadiansToDegrees(Float(atan2(xPP, yPP)))
    let roundedAngle = Int(angle.rounded())
    
    return roundedAngle
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
        
        guard let namesDict = namesDict as? Dictionary<String, Array<String>>,
            let firstNames = namesDict["first_names"], let middleNames = namesDict["middle_names"],
            let lastNames = namesDict["last_names"], let badNames = namesDict["bad_names"] else {
                NSLog("Could not load name dictionary.")
                return nil
        }
		
		 // grab bits from the MAC address (6 bits, 6 bits, 8 bits => last, middle, first)
		 // (5 digis of mac address is 20 bits) llllllmmmmmmffffffff
		 
		let macNumber = mac
		let offset = (macNumber & 0xFF) % 16
		let firstIndex = ((macNumber & 0xFF) + offset) % firstNames.count
		var middleIndex = (((macNumber >> 8) & 0b111111) + offset) % middleNames.count
		let lastIndex = (((macNumber >> (8+6)) & 0b111111) + offset) % lastNames.count
		
        var name: String?
        var abbreviatedName = ""
        repeat {
            let firstName = firstNames[firstIndex]
            let middleName = middleNames[middleIndex]
            let lastName = lastNames[lastIndex]
            
            abbreviatedName = String(firstName.prefix(1) + middleName.prefix(1) + lastName.prefix(1))
            name = firstName + " " + middleName + " " + lastName
            //print("\(deviceName) \(mac) \(firstIndex), \(middleIndex), \(lastIndex); \(abbreviatedName) \(name ?? "?")")
            
            //if the abbreviation is in the bad words list, move to the next middle name
            middleIndex = (middleIndex + 1) % middleNames.count

        } while badNames.contains(abbreviatedName)
		
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

/**
 Converts a note number to a period in microseconds (us)
 See: https://newt.phys.unsw.edu.au/jw/notes.html
  fm  =  (2^((m−69)/12))(440 Hz)
 */
public func noteToPeriod(_ note: UInt8) -> UInt16? {
    
    let frequency = 440 * pow(Double(2), Double((Double(note) - 69)/12))
    let period = (1/frequency) * 1000000
    if period > 0 && period <= Double(UInt16.max) {
        return UInt16(period)
    } else {
        return nil
    }
}

enum BatteryStatus: Int {
    case red = 0, yellow, green
}

enum BBTrobotConnectStatus {
    case oughtToBeConnected, shouldBeDisconnected, attemptingConnection
}
