//
//  FlutterPeripheral.swift
//  BirdBlox
//
//  Created by birdbrain on 3/23/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import CoreBluetooth

class FlutterPeripheral: NSObject, CBPeripheralDelegate, BBTRobotBLEPeripheral {
	public static let deviceUUID = CBUUID(string: "BC2F4CC6-AAEF-4351-9034-D66268E328F0")
    static let SERVICE_UUID =      CBUUID(string: "BC2F4CC6-AAEF-4351-9034-D66268E328F0")
    static let TX_UUID =           CBUUID(string: "06D1E5E7-79AD-4A71-8FAA-373789F7D93C")
    static let RX_UUID =           CBUUID(string: "818AE306-9C5B-448D-B51A-7ADD6A5D314D")
    static let RX_CONFIG_UUID =    CBUUID(string: "00002902-0000-1000-8000-00805f9b34fb")
	
	
	public let peripheral: CBPeripheral
	
	public var id: String {
		return self.peripheral.identifier.uuidString
	}
	
	public static let type: BBTRobotType = .Flutter
	
	private var _initialized: Bool = false
	public var initialized: Bool {
		return self._initialized
	}
    
    var rx_line, tx_line: CBCharacteristic?
    var rx_config_line: CBDescriptor?
    
    var data_cond: NSCondition = NSCondition()
    
    fileprivate var servos: [UInt8] = [0,0,0]
    fileprivate var servos_time: [Double] = [0,0,0]
    fileprivate var trileds: [[UInt8]] = [[0,0,0],[0,0,0],[0,0,0]]
    fileprivate var trileds_time: [Double] = [0,0,0]
	fileprivate var buzzerVolume: Int = 0
	fileprivate var buzzerFrequency: Int = 0
	fileprivate var buzzerTime: Double = 0
	
	let OK_RESPONSE = "OK"
	let FAIL_RESPONSE = "FAIL"
	let MAX_RETRY = 50
	
    let cache_timeout: Double = 15.0 //in seconds
    
    
    init(peripheral: CBPeripheral){
        self.peripheral = peripheral
		
        super.init()
        self.peripheral.delegate = self
        
        self.peripheral.discoverServices([FlutterPeripheral.SERVICE_UUID])
    }
    
    /**
     * This is called when a service is discovered for a peripheral
     * We specifically want the GATT service and start discovering characteristics
     * for that GATT service
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if (peripheral != self.peripheral || error != nil) {
            //not the right device
            return
        }
        if let services = peripheral.services{
            for service in services {
                if(service.uuid == FlutterPeripheral.SERVICE_UUID){
                    peripheral.discoverCharacteristics([FlutterPeripheral.RX_UUID,
                                                        FlutterPeripheral.TX_UUID], for: service)
                    return
                }
            }
        }
    }
    /**
     * Once we find a characteristic, we check if it is the RX or TX line that was
     * found. Once we have found both, we begin looking for descriptors
     */
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {
		print("Peripheral \(peripheral) discovered service \(service)")
		if (peripheral != self.peripheral || error != nil) {
            //not the right device
            return
        }
        var wasTXSet = false
        var wasRXSet = false
        if let characteristics = service.characteristics{
            for characteristic in characteristics {
                if(characteristic.uuid == FlutterPeripheral.TX_UUID){
                    tx_line = characteristic
                    peripheral.setNotifyValue(true, for: characteristic )
                    wasTXSet = true
                }
                else if(characteristic.uuid == FlutterPeripheral.RX_UUID){
                    rx_line = characteristic
                    peripheral.setNotifyValue(true, for: characteristic )
                    wasRXSet = true
                }
                if(wasTXSet && wasRXSet){
                    peripheral.discoverDescriptors(for: rx_line!)
                    return
                }
            }
        }
    }
    
    /**
     * We want a specific characteristic on the RX line that is used for data
     */
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        if (peripheral != self.peripheral || error != nil || characteristic != rx_line!) {
            //not the right device
            return
        }
        if let descriptors = characteristic.descriptors {
            for descriptor in descriptors {
                if descriptor.uuid == FlutterPeripheral.RX_CONFIG_UUID {
                    rx_config_line = descriptor
                    peripheral.setNotifyValue(true, for: rx_line!)
                    initialize()
                    return
                }
            }
        }

        
    }
    
    /**
     * Called when a descriptor is updated
     */
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        if descriptor != rx_config_line {
            return
        }
        data_cond.lock()
        data_cond.signal()
        data_cond.unlock()
    }
    
    /**
     * Called when we update a characteristic
     */
    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic != tx_line {
            return
        }
        data_cond.lock()
        data_cond.signal()
        data_cond.unlock()
    }
    
    private func initialize() {
        self._initialized = true
        print("flutter initialized")
    }
	
	public func endOfLifeCleanup() -> Bool {
		return true
	}
    
	public var connected: Bool {
        return peripheral.state == CBPeripheralState.connected
    }
    
    func sendDataWithResponse(data: Data) -> String {
		guard let tx_line = self.tx_line else {
			NSLog("Has not discovered tx line yet.")
			return FAIL_RESPONSE
		}
		
        data_cond.lock()
        peripheral.writeValue(data, for: tx_line, type: CBCharacteristicWriteType.withoutResponse)
        //peripheral.writeValue(data, for: rx_config_line!)
		data_cond.wait(until: Date(timeIntervalSinceNow: 0.1))
        data_cond.unlock()
        
        let response = tx_line.value
        if let safe_response = response {
            let data_string = String(data: safe_response, encoding: .utf8)
            return data_string!
        }
        return FAIL_RESPONSE
    }
    
    func sendDataWithoutResponse(data: Data) {
        var response: String? = FAIL_RESPONSE
        var counter = 0
        while(response != OK_RESPONSE) {
            response = sendDataWithResponse(data: data)
            counter += 1
            if counter >= MAX_RETRY {
				let dataArray = [UInt8](data)
                print("failed to send data: \(dataArray)")
                return
            }
        }
    }
    
    //What follows are all the functions for setting outputs and getting inputs
    func setTriLED(port: UInt, intensities: BBTTriLED) -> Bool {
        let i = Int(port - 1)
		let (r, g, b) = (intensities.red, intensities.green, intensities.blue)
        let current_time = NSDate().timeIntervalSince1970
        if(trileds[i] == [r,g,b] && (current_time - trileds_time[i]) < cache_timeout){
			print("triled command not sent because it has been cached.")
            return true //Still successful in getting LED to be the right value
        }
		let command = BBTFlutterUtility.ledCommand(UInt8(port), r: r, g: g, b: b)
        self.sendDataWithoutResponse(data: command)
        trileds[i] = [r,g,b]
        trileds_time[i] = current_time
		
//		print("triled command sent \(r) \(g) \(b)")
        
        return true
    }
    
    func setServo(port: UInt, angle: UInt8) -> Bool {
        let i = Int(port - 1)
        let current_time = NSDate().timeIntervalSince1970
        if(servos[i] == angle && (current_time - servos_time[i]) < cache_timeout){
            return true //Still successful in getting output to be the right value
        }
        let command: Data = BBTFlutterUtility.servoCommand(UInt8(port), angle: angle)
        servos[i] = angle
        servos_time[i] = current_time
        self.sendDataWithoutResponse(data: command)
        return true
    }
	
	func setBuzzer(volume: Int, frequency: Int) -> Bool
	{
		let current_time = NSDate().timeIntervalSince1970
		if(buzzerVolume == volume &&
		   buzzerFrequency == frequency &&
		   (current_time - buzzerTime) < cache_timeout){
			return true //Still successful in getting output to be the right value
		}
		
		let command: Data = BBTFlutterUtility.buzzerCommand(vol: volume, freq: frequency)
		
		buzzerVolume = volume
		buzzerFrequency = frequency
		buzzerTime = current_time
		
		self.sendDataWithoutResponse(data: command)
		return true
	}
	
	public func setAllOutputsToOff() -> Bool {
		//The order of output to shut off are: buzzer, servos, LEDs
		//Beware of shortcuts in boolean logic
		
		var suc = true
		suc = self.setBuzzer(volume: 0, frequency: 0) && suc
		for i in UInt(1)...3 {
			suc = self.setServo(port: i, angle: BBTFlutterUtility.servoOffAngle) && suc
		}
		for i in UInt(1)...3 {
			suc = self.setTriLED(port: i, intensities: BBTTriLED(0, 0, 0)) && suc
		}
		
		return suc
	}
	
	public var sensorValues: [UInt8] {
		var response: String = sendDataWithResponse(data: BBTFlutterUtility.readCommand)
		var values = response.split(",")
		var counter = 0
		//this just gets the 0th character of values[0] (which should only be 1
		//character and checks to see if it is the flutter response char
		while(getUnicode(values[0][values[0].index(values[0].startIndex, offsetBy: 0)]) !=
			BBTFlutterUtility.responseCharacter) {
				print("Got invalid response: " + response)
				response = sendDataWithResponse(data: BBTFlutterUtility.readCommand)
				values = response.split(",")
				counter += 1
				if counter >= MAX_RETRY {
					print("failed to send read command")
					break
				}
		}
		
		let sp1 = UInt8(values[1])
		let sp2 = UInt8(values[2])
		let sp3 = UInt8(values[3])
		
		guard let sensorPercent1 = sp1,
			let sensorPercent2 = sp2,
			let sensorPercent3 = sp3 else {
				return [0, 0, 0]
		}
		
		return [sensorPercent1, sensorPercent2, sensorPercent3]
	}
	
	
    func getSensor(port: Int, input_type: String) -> Int? {
		let percent = self.sensorValues[port - 1]
		
        let value = percentToRaw(percent)
		
        switch input_type {
        case "distance":
            return rawToDistance(value)
        case "temperature":
            print("temp sensor \(value)")
            print("rtt \(rawToTemp(value))")
            return rawToTemp(value)
        case "soil":
            return bound(Int(percent), min: 0, max: 90)
        default:
            return Int(percent)
        }
    }
}
