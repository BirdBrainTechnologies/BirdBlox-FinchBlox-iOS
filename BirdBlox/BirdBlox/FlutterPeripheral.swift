//
//  FlutterPeripheral.swift
//  BirdBlox
//
//  Created by birdbrain on 3/23/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import CoreBluetooth

class FlutterPeripheral: NSObject, CBPeripheralDelegate {
    fileprivate var peripheral: CBPeripheral
    fileprivate let BLE_Manager: BLECentralManager

    static let DEVICE_UUID =     CBUUID(string: "BC2F4CC6-AAEF-4351-9034-D66268E328F0")
    static let SERVICE_UUID =    CBUUID(string: "BC2F4CC6-AAEF-4351-9034-D66268E328F0")
    static let TX_UUID =         CBUUID(string: "06D1E5E7-79AD-4A71-8FAA-373789F7D93C")
    static let RX_UUID =         CBUUID(string: "818AE306-9C5B-448D-B51A-7ADD6A5D314D")
    static let RX_CONFIG_UUID =  CBUUID(string: "00002902-0000-1000-8000-00805f9b34fb")
    
    let OK_RESPONSE = "OK"
    let FAIL_RESPONSE = "FAIL"
    let MAX_RETRY = 50
    
    var rx_line, tx_line: CBCharacteristic?
    var rx_config_line: CBDescriptor?
    
    var last_message_sent: Data = Data()
    
    var data_cond: NSCondition = NSCondition()
    
    fileprivate var servos: [UInt8] = [0,0,0]
    fileprivate var servos_time: [Double] = [0,0,0]
    fileprivate var trileds: [[UInt8]] = [[0,0,0],[0,0,0],[0,0,0]]
    fileprivate var trileds_time: [Double] = [0,0,0]
	fileprivate var buzzerVolume: Int = 0
	fileprivate var buzzerFrequency: Int = 0
	fileprivate var buzzerTime: Double = 0
	
    var last_message_recieved: [UInt8] = [0,0,0]
    let cache_timeout: Double = 15.0 //in seconds
    var was_initialized = false
    
    
    init(peripheral: CBPeripheral){
        self.peripheral = peripheral
        self.BLE_Manager = BLECentralManager.manager
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
    
    fileprivate func initialize() {
        was_initialized = true
        print("init")
    }
    
    func disconnect() {
        BLE_Manager.disconnect(peripheral: peripheral)
    }
    
    func isConnected () -> Bool {
        return peripheral.state == CBPeripheralState.connected
    }
    
    func sendDataWithResponse(data: Data) -> String{
        data_cond.lock()
        peripheral.writeValue(data, for: tx_line!, type: CBCharacteristicWriteType.withoutResponse)
        //peripheral.writeValue(data, for: rx_config_line!)
		data_cond.wait(until: Date(timeIntervalSinceNow: 0.1))
        data_cond.unlock()
        
        let response = tx_line?.value
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
    func setTriLed(port: Int, r: UInt8, g: UInt8, b:UInt8) -> Bool {
        let i = port - 1
        let current_time = NSDate().timeIntervalSince1970
        if(trileds[i] == [r,g,b] && (current_time - trileds_time[i]) < cache_timeout){
			print("triled command not sent because it has been cached.")
            return true //Still successful in getting LED to be the right value
        }
        let command = getFlutterLedCommand(UInt8(port), r: r, g: g, b: b)
        self.sendDataWithoutResponse(data: command)
        trileds[i] = [r,g,b]
        trileds_time[i] = current_time
		
//		print("triled command sent \(r) \(g) \(b)")
        
        return true
    }
    
    func setServo(port: Int, angle: UInt8) -> Bool {
        let i = port - 1
        let current_time = NSDate().timeIntervalSince1970
        if(servos[i] == angle && (current_time - servos_time[i]) < cache_timeout){
            return false
        }
        let command: Data = getFlutterServoCommand(UInt8(port), angle: angle)
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
			return false
		}
		
		let command: Data = getFlutterBuzzerCommand(vol: volume, freq: frequency)
		
		buzzerVolume = volume
		buzzerFrequency = frequency
		buzzerTime = current_time
		
		self.sendDataWithoutResponse(data: command)
		return true
	}
	
    func getSensor(port: Int, input_type: String) -> Int? {
        var response: String = sendDataWithResponse(data: getFlutterRead())
        var values = response.split(",")
        var counter = 0
        //this just gets the 0th character of values[0] (which should only be 1 
        //character and checks to see if it is the flutter response char
        while(getUnicode(values[0][values[0].index(values[0].startIndex, offsetBy: 0)]) !=
			BBTFlutterResponseCharacter) {
            print("Got invalid response: " + response)
            response = sendDataWithResponse(data: getFlutterRead())
            values = response.split(",")
            counter += 1
            if counter >= MAX_RETRY {
                print("failed to send read command")
                return nil
            }
        }
        let data_percent = UInt8(values[port])!
        let data = percentToRaw(data_percent)
        switch input_type {
        case "distance":
            return rawToDistance(data)
        case "temperature":
            print("temp sensor \(data)")
            print("rtt \(rawToTemp(data))")
            return rawToTemp(data)
        case "soil":
            return bound(Int(data_percent), min: 0, max: 90)
        default:
            return Int(data_percent)
        }
    }
}
