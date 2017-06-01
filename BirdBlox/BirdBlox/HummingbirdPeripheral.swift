//
//  HummingbirdPeripheral.swift
//  BirdBlox
//
//  Created by birdbrain on 3/23/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import CoreBluetooth

class HummingbirdPeripheral: NSObject, CBPeripheralDelegate {
    fileprivate var peripheral: CBPeripheral
    fileprivate let BLE_Manager: BLECentralManager
    static let DEVICE_UUID         = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")//BLE adapter
    static let SERVICE_UUID        = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")//UART Service
    static let TX_UUID             = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")//sending
    static let RX_UUID             = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")//receiving
    static let RX_CONFIG_UUID      = CBUUID(string: "00002902-0000-1000-8000-00805f9b34fb")
    var rx_line, tx_line: CBCharacteristic?
    
    var last_message_sent: Data = Data()
    
    fileprivate var vibrations: [UInt8] = [0,0]
    fileprivate var vibrations_time: [Double] = [0,0]
    fileprivate var motors: [Int] = [0,0]
    fileprivate var motors_time: [Double] = [0,0]
    fileprivate var servos: [UInt8] = [0,0,0,0]
    fileprivate var servos_time: [Double] = [0,0,0,0]
    fileprivate var leds: [UInt8] = [0,0,0,0]
    fileprivate var leds_time: [Double] = [0,0,0,0]
    fileprivate var trileds: [[UInt8]] = [[0,0,0],[0,0,0]]
    fileprivate var trileds_time: [Double] = [0,0]
    var last_message_recieved: [UInt8] = [0,0,0,0]
    let cache_timeout: Double = 15.0 //in seconds
    var was_initialized = false
	var resettingName = false
	var gettingMAC = false
	var commandMode = false
	var initializing = false
    fileprivate var setTimer: Timer = Timer()
	
	static let ADALE_COMMAND_MODE_TOGGLE = "+++"
	static let ADALE_GET_MAC = "AT+BLEGETADDR"
	static let ADALE_SET_NAME = "AT+GAPDEVNAME="
	static let ADALE_RESET = "ATZ"
	static let NAME_PREFIX = "HB"
	var macStr: String? = nil
	let macReplyLen = 17

    
    init(peripheral: CBPeripheral){
        self.peripheral = peripheral
        self.BLE_Manager = BLECentralManager.manager
        super.init()
        self.peripheral.delegate = self
        
        self.peripheral.discoverServices([HummingbirdPeripheral.SERVICE_UUID])
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
                if(service.uuid == HummingbirdPeripheral.SERVICE_UUID){
                    peripheral.discoverCharacteristics([HummingbirdPeripheral.RX_UUID,
                                                        HummingbirdPeripheral.TX_UUID],
														for: service)
                    return
                }
            }
        }
    }
    /**
     * Once we find a characteristic, we check if it is the RX or TX line that was
     * found. Once we have found both, we send a notification saying the device
     * is now conencted
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
                if(characteristic.uuid == HummingbirdPeripheral.TX_UUID){
                    tx_line = characteristic
                    peripheral.setNotifyValue(true, for: characteristic )
                    wasTXSet = true
                }
                else if(characteristic.uuid == HummingbirdPeripheral.RX_UUID){
                    rx_line = characteristic
                    peripheral.setNotifyValue(true, for: characteristic )
                    wasRXSet = true
                }
                if(wasTXSet && wasRXSet){
                    self.beginInitialization()
                    return
                }
            }
        }
    }
	
	static func nameNeedsReset(_ name: String) -> Bool {
		let HB_DEFAULT_NAME = "Adafruit Bluefruit LE"
		if name == HB_DEFAULT_NAME {
			return true
		}
		return false
	}
    
    fileprivate func beginInitialization() {
		self.initializing = true
		
		//Get ourselves a fresh slate
        self.sendData(data: getTurnOffCommand())
        Thread.sleep(forTimeInterval: 0.1)
        self.sendData(data: getPollStopCommand())
        Thread.sleep(forTimeInterval: 0.1)
		
		
		//Check the name
		if HummingbirdPeripheral.nameNeedsReset(self.peripheral.name!) {
			NSLog("Deciding to reset hummingbird name")
			self.resettingName = true
			self.enterCommandMode()
			self.getMAC()
		}
		else {
			self.finishInitialization()
		}
    }
	
	fileprivate func getMAC() {
		if self.commandMode {
			//Causes self.macStr to be set when mac address received
			self.gettingMAC = true
			self.sendData(data: Data(bytes: Array(HummingbirdPeripheral.ADALE_GET_MAC.utf8)))
		}
	}
	
	fileprivate func resetNameFromMAC() {
		if self.commandMode && self.macStr != nil{
			let name = HummingbirdPeripheral.NAME_PREFIX +
				String(describing: self.macStr!.utf8.dropFirst(12 - 5))
			self.sendData(data: Data(bytes: Array((HummingbirdPeripheral.ADALE_SET_NAME + name).utf8)))
			Thread.sleep(forTimeInterval: 0.1)
			
			print("Resetting name to " + name)
			
			self.resetHummingBird()
			
			if self.initializing {
				self.finishInitialization()
			}
		}
	}
	
	fileprivate func finishInitialization() {
		self.initializing = false
		
		if self.commandMode {
			self.exitCommandMode()
		}
		
		self.sendData(data: getPollStartCommand())
		DispatchQueue.main.async{
			self.setTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self,
			                                     selector: #selector(HummingbirdPeripheral.setAll),
			                                     userInfo: nil, repeats: true)
			self.setTimer.fire()
		}
		was_initialized = true
	}
	
	fileprivate func enterCommandMode() {
		if !self.commandMode {
			self.commandMode = true
			self.sendData(data: Data(HummingbirdPeripheral.ADALE_COMMAND_MODE_TOGGLE.utf8))
			Thread.sleep(forTimeInterval: 0.1)
		}
	}
	
	fileprivate func exitCommandMode() {
		if self.commandMode {
			self.sendData(data: Data(HummingbirdPeripheral.ADALE_COMMAND_MODE_TOGGLE.utf8))
			Thread.sleep(forTimeInterval: 0.1)
			self.commandMode = false
		}
	}
	
	fileprivate func resetHummingBird() {
		if self.commandMode {
			self.sendData(data: Data(HummingbirdPeripheral.ADALE_RESET.utf8))
			Thread.sleep(forTimeInterval: 0.1)
			self.commandMode = false
		}
	}
	
	
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
		//If we are trying to reset the hummingbird's name, this should be the device's MAC
		print("Did update characteristic \(characteristic)")
		
        if characteristic.uuid != HummingbirdPeripheral.RX_UUID {
			return
        }
		
		print("Is RX UUID")
		print("number of bytes \(characteristic.value!.count)")
		
		if self.gettingMAC && characteristic.value!.count == self.macReplyLen {
			
		objc_sync_enter(self.peripheral)
		var macBuffer = [UInt8](repeatElement(0, count: self.macReplyLen))
		(characteristic.value! as NSData).getBytes(&macBuffer, length: self.macReplyLen)
		objc_sync_exit(self.peripheral)
		
			macBuffer = (macBuffer as NSArray).filtered(using: NSPredicate(block: {
				(byte, bind) in
				(byte as! UInt8) == 58
			})) as! [UInt8]
			
			self.macStr = NSString(bytes: &macBuffer, length: macBuffer.count,
								   encoding: String.Encoding.ascii.rawValue)! as String
			
			self.gettingMAC = false
			print("Got mac address \(self.macStr!).")
			
			if self.resettingName {
				self.resetNameFromMAC()
			}
			if self.initializing {
				self.finishInitialization()
			}
			
			return
		}
		
        if characteristic.value!.count % 5 != 0 {
            return
        }
        objc_sync_enter(self.peripheral)
        (characteristic.value! as NSData).getBytes(&self.last_message_recieved, length: 4)
        objc_sync_exit(self.peripheral)
    }
    
    /**
     * Called when we update a characteristic (when we write to the HB)
     */
    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
		if let error = error {
			NSLog("Unable to write to hummingbird due to error \(error)")
		}
        print("did write value for characteristic \(characteristic)")
    }
    
    func disconnect() {
        BLE_Manager.disconnect(peripheral: peripheral)
    }
    
    func isConnected () -> Bool {
        return peripheral.state == CBPeripheralState.connected
    }
    
    func getData() -> [UInt8]? {
        return self.last_message_recieved
    }
    
    func sendData(data: Data) {
		if self.isConnected() {
			peripheral.writeValue(data, for: tx_line!, type: CBCharacteristicWriteType.withResponse)
			
			if self.commandMode {
				print("Sent command: " +
					(NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String))
			}
		}
    }
    
    
    //What follows are all the functions for setting outputs and getting inputs
    //Most of this code has been commented out as we switch to the new method
    //of setting outputs 
    //TODO: add a check for legacy firmware and use set all for only
    //firmwares newer than 2.2.a 
    func setLED(port: Int, intensity: UInt8) -> Bool {
        let i = port - 1
        /*
        let current_time = NSDate().timeIntervalSince1970
        if(leds[i] == intensity && (current_time - leds_time[i]) < cache_timeout){
            return false
        }
        let command: Data = getLEDCommand(UInt8(port), intensity: intensity)
        self.sendData(data: command)
        leds_time[i] = current_time
        */
        leds[i] = intensity
        return true
    }
    
    func setTriLed(port: Int, r: UInt8, g: UInt8, b:UInt8) -> Bool {
        let i = port - 1
        /*
        let current_time = NSDate().timeIntervalSince1970
        if(trileds[i] == [r,g,b] && (current_time - trileds_time[i]) < cache_timeout){
            return false
        }
        let command = getTriLEDCommand(UInt8(port), red_val: r, green_val: g, blue_val: b)
        self.sendData(data: command)
        trileds_time[i] = current_time
         */
        trileds[i] = [r,g,b]

        return true
    }
    
    func setVibration(port: Int, intensity: UInt8) -> Bool {
        let i = port - 1
        /*
        let current_time = NSDate().timeIntervalSince1970
        if(vibrations[i] == intensity && (current_time - vibrations_time[i]) < cache_timeout){
            return false
        }
        let command: Data = getVibrationCommand(UInt8(port), intensity: intensity)
        
        self.sendData(data: command)
        vibrations_time[i] = current_time
        */
        vibrations[i] = intensity
        return true
    }
    
    func setMotor(port: Int, speed: Int) -> Bool {
        let i = port - 1
        /*
        let current_time = NSDate().timeIntervalSince1970
        if(motors[i] == speed && (current_time - motors_time[i]) < cache_timeout){
            return false
        }
        let command: Data = getMotorCommand(UInt8(port), speed: speed)
        self.sendData(data: command)
        motors_time[i] = current_time
        */
        motors[i] = speed
        return true
    }
    
    func setServo(port: Int, angle: UInt8) -> Bool {
        let i = port - 1
        /*
        let current_time = NSDate().timeIntervalSince1970
        if(servos[i] == angle && (current_time - servos_time[i]) < cache_timeout){
            return false
        }
        let command: Data = getServoCommand(UInt8(port), angle: angle)
        self.sendData(data: command)
        servos_time[i] = current_time
        */
        servos[i] = angle
        return true
    }
    
    func setAll() {
        let command = getSetAllCommand(tri: trileds, leds: leds, servos: servos,
                                       motors: motors, vibs: vibrations)
        print("Setting All: " + command.description)
        self.sendData(data: command)
    }
}
