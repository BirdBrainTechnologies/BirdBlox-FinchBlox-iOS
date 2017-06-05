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
	
	//MARK: Variables for HB renaming
	static let ADALE_COMMAND_MODE_TOGGLE = "+++\n"
	static let ADALE_GET_MAC = "AT+BLEGETADDR\n"
	static let ADALE_SET_NAME = "AT+GAPDEVNAME="
	static let ADALE_RESET = "ATZ\n"
	static let NAME_PREFIX = "HB"
	var macStr: String? = nil
	let macReplyLen = 17
	let macLen = 12
	var oneOffTimer: Timer = Timer()

    
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
    
    fileprivate func beginInitialization() {
		self.initializing = true
		
		//Get ourselves a fresh slate
        self.sendData(data: getTurnOffCommand())
        Thread.sleep(forTimeInterval: 0.1)
        self.sendData(data: getPollStopCommand())
        Thread.sleep(forTimeInterval: 0.1)
		
		self.finishInitialization()
		
		//For HB renaming
//		//Check the name
//		if HummingbirdPeripheral.nameNeedsReset(self.peripheral.name!) {
//			NSLog("Deciding to reset hummingbird name")
//			self.resettingName = true
//			self.enterCommandMode()
//			
//			DispatchQueue.main.sync {
//				let _ = Timer.scheduledTimer(timeInterval: 0.6, target: self,
//					                     selector: #selector(HummingbirdPeripheral.getMAC),
//					                     userInfo: nil, repeats: false)
//			}
//			
//			DispatchQueue.main.sync {
//				let _ = Timer.scheduledTimer(timeInterval: 2.0, target: self,
//									 selector: #selector(HummingbirdPeripheral.resetNameFromMAC),
//									 userInfo: nil, repeats: false)
//			}
//			
//			DispatchQueue.main.sync {
//				let _ = Timer.scheduledTimer(timeInterval: 3.0, target: self,
//				                     selector:#selector(HummingbirdPeripheral.finishInitialization),
//				                     userInfo: nil, repeats: false)
//			}
//		}
//		else {
//			self.finishInitialization()
//		}
    }
	
	@objc fileprivate func finishInitialization() {
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
		self.was_initialized = true
	}
	
	
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
		//If we are trying to reset the hummingbird's name, this should be the device's MAC
		print("Did update characteristic \(characteristic)")
		
        if characteristic.uuid != HummingbirdPeripheral.RX_UUID {
			return
        }
		
//		if self.gettingMAC && characteristic.value!.count >= self.macReplyLen {
//			
//			objc_sync_enter(self.peripheral)
//			var macBuffer = [UInt8](repeatElement(0, count: self.macReplyLen))
//			(characteristic.value! as NSData).getBytes(&macBuffer, length: self.macReplyLen)
//			objc_sync_exit(self.peripheral)
//			
//			macBuffer = (macBuffer as NSArray).filtered(using: NSPredicate(block: {
//				(byte, bind) in
//				(byte as! UInt8) != 58
//			})) as! [UInt8]
//
//			self.macStr = NSString(bytes: &macBuffer, length: self.macLen,
//								   encoding: String.Encoding.ascii.rawValue)! as String
//			
//			self.gettingMAC = false
//			print("Got mac address `\(self.macStr!)`")
//			
////			if self.resettingName {
////				//Wait for the HB to finish sending its reply, or it will ignore our commands.
////				print("Setting timer")
////				DispatchQueue.main.sync {
////					self.oneOffTimer =
////					Timer.scheduledTimer(timeInterval: 0.5, target: self,
////										 selector: #selector(HummingbirdPeripheral.resetNameFromMAC),
////										 userInfo: nil, repeats: false)
////				}
////			}
////			if self.initializing {
////				self.finishInitialization()
////			}
//			
//			return
//		}
		
		
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
//        print("did write value for characteristic")
    }
    
    func disconnect() {
        BLE_Manager.disconnect(peripheral: peripheral)
		self.setTimer.invalidate()
    }
    
    func isConnected () -> Bool {
        return peripheral.state == CBPeripheralState.connected
    }
    
    func getData() -> [UInt8]? {
        return self.last_message_recieved
    }
    
    func sendData(data: Data) {
		if self.isConnected() {
			peripheral.writeValue(data, for: tx_line!, type: .withResponse)
			
			if self.commandMode {
				print("Sent command: " +
					(NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String))
			}
			else {
//				print("Sent non-command mode message")
			}
		}
		else{
			print("Not connected")
		}
    }
    
    
    //What follows are all the functions for setting outputs and getting inputs
    //Most of this code has been commented out as we switch to the new method
    //of setting outputs 
    //TODO: add a check for legacy firmware and use set all for only
    //firmwares newer than 2.2.a 
    func setLED(port: Int, intensity: UInt8) -> Bool {
        let i = port - 1
		
        leds[i] = intensity
        return true
    }
    
    func setTriLed(port: Int, r: UInt8, g: UInt8, b:UInt8) -> Bool {
        let i = port - 1
		
        trileds[i] = [r,g,b]

        return true
    }
    
    func setVibration(port: Int, intensity: UInt8) -> Bool {
        let i = port - 1
		
        vibrations[i] = intensity
        return true
    }
    
    func setMotor(port: Int, speed: Int) -> Bool {
        let i = port - 1
		
        motors[i] = speed
        return true
    }
    
    func setServo(port: Int, angle: UInt8) -> Bool {
        let i = port - 1
		
        servos[i] = angle
        return true
    }
    
    func setAll() {
		if self.was_initialized {
			let command = getSetAllCommand(tri: trileds, leds: leds, servos: servos,
			                               motors: motors, vibs: vibrations)
			let bytes = UnsafeMutableBufferPointer<UInt8>(start: UnsafeMutablePointer<UInt8>.allocate(capacity: 20), count: 19)
			let _ = command.copyBytes(to: bytes)
			print("Setting All: \(bytes.map({return $0}))")
			self.sendData(data: command)
		}
    }
	
	
//MARK: Code for renaming Hummingbirds

	fileprivate func enterCommandMode() {
		if !self.commandMode {
			print("Entering command mode")
			self.commandMode = true
			self.sendData(data: Data(HummingbirdPeripheral.ADALE_COMMAND_MODE_TOGGLE.utf8))
			Thread.sleep(forTimeInterval: 0.1)
		}
	}
	
	@objc fileprivate func exitCommandMode() {
		if self.commandMode {
			self.sendData(data: Data(HummingbirdPeripheral.ADALE_COMMAND_MODE_TOGGLE.utf8))
			Thread.sleep(forTimeInterval: 0.1)
			self.commandMode = false
			print("Exited command mode")
		}
	}
	
	@objc fileprivate func resetHummingBird() {
		if self.commandMode {
			self.sendData(data: Data(HummingbirdPeripheral.ADALE_RESET.utf8))
			Thread.sleep(forTimeInterval: 0.1)
			self.commandMode = false
		}
	}
	
	func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
		print("Peripheral updated name: " + peripheral.name!)
	}
	
	@objc fileprivate func getMAC() {
		if self.commandMode {
			//Causes self.macStr to be set when mac address received
			print("Getting MAC")
			self.gettingMAC = true
			self.sendData(data: Data(bytes: Array(HummingbirdPeripheral.ADALE_GET_MAC.utf8)))
			print(Array(HummingbirdPeripheral.ADALE_GET_MAC.utf8))
			
			//D748F96DA17C
		}
	}
	
	@objc fileprivate func resetNameFromMAC() {
		if self.commandMode && self.macStr != nil{
//			let macStr = self.macStr!
//			let name = HummingbirdPeripheral.NAME_PREFIX +
//							String(macStr.characters.dropFirst(macStr.characters.count - 5))
			
			
			self.sendData(data: Data(bytes: Array("AT+GAPDEVNAME=menche\n".utf8)))
			
			//			print(Array((HummingbirdPeripheral.ADALE_SET_NAME +
			//				name + "\n").utf8))
			//
			//			print("Resetting name to " + name)
			
			//			self.exitCommandMode()
			print("Setting timer for HB BLE reset")
			//			DispatchQueue.main.sync{
			//				Timer.scheduledTimer(timeInterval: 1.0, target: self,
			//									 selector: #selector(HummingbirdPeripheral.resetHummingBird),
			//									 userInfo: nil, repeats: false)
			//			}
			//			Thread.sleep(forTimeInterval: 1.0)
			//			self.disconnect()
			
			if self.initializing {
				//				self.finishInitialization()
			}
		}
		else {
			print("not resetting name anymore")
		}
	}
	
	static func nameNeedsReset(_ name: String) -> Bool {
		let HB_DEFAULT_NAME = "Adafruit Bluefruit LE"
		if name == HB_DEFAULT_NAME {
			return true
		}
		return false
	}
}
