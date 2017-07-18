//
//  HummingbirdPeripheral.swift
//  BirdBlox
//
//  Created by birdbrain on 3/23/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import CoreBluetooth

class HummingbirdPeripheral: NSObject, CBPeripheralDelegate, BBTRobotBLEPeripheral {
	public let peripheral: CBPeripheral
	public var id: String {
		return peripheral.identifier.uuidString
	}
	
	public static let type: BBTRobotType = .Hummingbird
	
    private let BLE_Manager: BLECentralManager
	
	//BLE adapter
	public static let deviceUUID    = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
	//UART Service
    static let SERVICE_UUID   = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
	//sending
    static let TX_UUID        = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
	//receiving
	static let RX_UUID        = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    static let RX_CONFIG_UUID = CBUUID(string: "00002902-0000-1000-8000-00805f9b34fb")
    var rx_line, tx_line: CBCharacteristic?
	
	static let sensorByteCount = 4
	private var lastSensorUpdate: [UInt8] = Array<UInt8>(repeating: 0, count: sensorByteCount)
	var sensorValues: [UInt8] {
		return lastSensorUpdate
	}
	
	private var _initialized = false
	public var initialized: Bool {
		return self._initialized
	}
	
	
	//MARK: Variables to coordinate set all
	var writtenCondition: NSCondition = NSCondition()
	
	//MARK: Variables write protected by writtenCondition
	private var currentOutputState: BBTHummingbirdOutputState
	public var nextOutputState: BBTHummingbirdOutputState
	var lastWriteWritten: Bool = false
	var lastWriteStart: DispatchTime = DispatchTime.now()
	//End variables write protected by writtenCondition
    private var syncTimer: Timer = Timer()
	let syncInterval = 0.03125 //(32Hz)
	let cacheTimeoutDuration: UInt64 = 1 * 100_000_000 //units
	let waitRefreshTime = 0.5 //seconds
	
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
	var resettingName = false
	var gettingMAC = false
	var commandMode = false

    
    init(peripheral: CBPeripheral){
        self.peripheral = peripheral
        self.BLE_Manager = BLECentralManager.manager
		
		self.currentOutputState = BBTHummingbirdOutputState()
		self.nextOutputState = BBTHummingbirdOutputState()
		
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
    
    private func beginInitialization() {
		//Get ourselves a fresh slate
        self.sendData(data: BBTHummingbirdUtility.getTurnOffCommand())
        Thread.sleep(forTimeInterval: 0.1)
        self.sendData(data: BBTHummingbirdUtility.getPollStopCommand())
        Thread.sleep(forTimeInterval: 0.1)
		
		self.finishInitialization()
    }
	
	@objc private func finishInitialization() {
		if self.commandMode {
			self.exitCommandMode()
		}
		
		self.sendData(data: BBTHummingbirdUtility.getPollStartCommand())
		DispatchQueue.main.async{
			self.syncTimer =
			Timer.scheduledTimer(timeInterval: self.syncInterval, target: self,
			                     selector: #selector(HummingbirdPeripheral.syncronizeOutputs),
			                     userInfo: nil, repeats: true)
			self.syncTimer.fire()
		}
		self._initialized = true
	}
	
	
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
		//If we are trying to reset the hummingbird's name, this should be the device's MAC
//		print("Did update characteristic \(characteristic)")
		
        if characteristic.uuid != HummingbirdPeripheral.RX_UUID {
			return
        }
		
		guard let inData = characteristic.value else {
			return
		}
		
        if characteristic.value!.count % 5 != 0 {
            return
        }
		
		//
        inData.copyBytes(to: &self.lastSensorUpdate, count: HummingbirdPeripheral.sensorByteCount)
    }
    
    /**
     * Called when we update a characteristic (when we write to the HB)
     */
    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
		if let error = error {
			NSLog("Unable to write to hummingbird due to error \(error)")
		}
		
		//We successfully sent a command
		self.writtenCondition.lock()
		self.lastWriteWritten = true
		self.writtenCondition.signal()
		
//		self.currentOutputState = self.nextOutputState.immutableCopy
		
		self.writtenCondition.unlock()
//		print(self.lastWriteStart)
    }
	
	//TODO: delete
    func disconnect() {
        BLE_Manager.disconnect(peripheral: peripheral)
		self.syncTimer.invalidate()
    }
	
	public func endOfLifeCleanup() -> Bool{
		self.syncTimer.invalidate()
		return true
	}
	
	public var connected: Bool {
        return peripheral.state == CBPeripheralState.connected
    }
    
    private func sendData(data: Data) {
		if self.connected {
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
	
	
	private func conditionHelper(condition: NSCondition, holdLock: Bool = true,
	                             predicate: (() -> Bool), work: (() -> ())) {
		if holdLock {
			condition.lock()
		}
		
		while !predicate() {
			condition.wait(until: Date(timeIntervalSinceNow: self.waitRefreshTime))
		}
		
		work()
		
		condition.signal()
		if holdLock {
			condition.unlock()
		}
	}
	
    //TODO: add a check for legacy firmware and use set all for only
    //firmwares newer than 2.2.a 
	//From Tom: send the characters 'G' '4' and you will get back the hardware version 
	//(currently 0x03 0x00) and the firmware version (0x02 0x02 'b'), might be 'a' instead of 'b'
    func setLED(port: Int, intensity: UInt8) -> Bool {
		guard self.peripheral.state == .connected else {
			return false
		}
	
        let i = port - 1
		
//		self.nextOutputState.leds[i] = intensity
//		
//		return true
		
		self.writtenCondition.lock()
//		print("written: \(self.lastWriteWritten), next: \(self.nextOutputState.leds[i])" +
//			" cur: \(self.currentOutputState.mutableCopy.leds[i])")
		
		while !(self.nextOutputState.leds[i] == self.currentOutputState.leds[i]) {
			self.writtenCondition.wait(until: Date(timeIntervalSinceNow: self.waitRefreshTime))
//			print("waiting. written: \(self.lastWriteWritten), next: \(self.nextOutputState.leds[i])")
//			print("cur: \(self.currentOutputState.mutableCopy.leds[i])")
		}
		
		self.nextOutputState.leds[i] = intensity
		
		self.writtenCondition.signal()
		self.writtenCondition.unlock()
		
		print("exit")
        return true
    }
    
	func setTriLED(port: UInt, intensities: BBTTriLED) -> Bool {
		guard self.peripheral.state == .connected else {
			return false
		}
		
        let i = Int(port - 1)
		let (r, g, b) = (intensities.red, intensities.green, intensities.blue)
		
		self.writtenCondition.lock()
		
		self.conditionHelper(condition: self.writtenCondition, holdLock: false,
		                     predicate: {
			self.nextOutputState.trileds[i] == self.currentOutputState.trileds[i]
		}, work: {
			self.nextOutputState.trileds[i] = BBTTriLED(red: r, green: g, blue: b)
		})
		
		self.writtenCondition.unlock()
		
		print("exit")
        return true
    }
    
    func setVibration(port: Int, intensity: UInt8) -> Bool {
		guard self.peripheral.state == .connected else {
			return false
		}
		
        let i = port - 1
		
		self.writtenCondition.lock()
		
		self.conditionHelper(condition: self.writtenCondition, holdLock: false,
		                     predicate: {
			self.nextOutputState.vibrators[i] == self.currentOutputState.vibrators[i]
		}, work: {
			self.nextOutputState.vibrators[i] = intensity
		})
		
		self.writtenCondition.unlock()
		
		
        return true
    }
    
    func setMotor(port: Int, speed: Int8) -> Bool {
		guard self.peripheral.state == .connected else {
			return false
		}
		
        let i = port - 1
		
		self.writtenCondition.lock()
		
		self.conditionHelper(condition: self.writtenCondition, holdLock: false,
		                     predicate: {
			self.nextOutputState.motors[i] == self.currentOutputState.motors[i]
		}, work: {
			self.nextOutputState.motors[i] = speed
		})
		
		self.writtenCondition.unlock()
		
		
        return true
    }
    
    func setServo(port: UInt, angle: UInt8) -> Bool {
		guard self.peripheral.state == .connected else {
			return false
		}
		
        let i = Int(port - 1)
		
		self.writtenCondition.lock()
		
		self.conditionHelper(condition: self.writtenCondition, holdLock: false,
		                     predicate: {
			self.nextOutputState.servos[i] == self.currentOutputState.servos[i]
		}, work: {
			self.nextOutputState.servos[i] = angle
		})
		
		self.writtenCondition.unlock()
		
		
        return true
    }
	
	
	func syncronizeOutputs() {
		self.writtenCondition.lock()
		
//		print("s ", separator: "", terminator: "")
		
		let nextCopy = self.nextOutputState
		
		let changeOccurred = !(nextCopy == self.currentOutputState)
		let currentCPUTime = DispatchTime.now().uptimeNanoseconds
		let shouldSync = changeOccurred ||
			((currentCPUTime - self.lastWriteStart.uptimeNanoseconds) > self.cacheTimeoutDuration)
		
		if self.initialized && self.lastWriteWritten  && shouldSync {
			let cmdMkr = BBTHummingbirdUtility.getSetAllCommand
			
			let tris = nextCopy.trileds
			let leds = nextCopy.leds
			let servos = nextCopy.servos
			let motors = nextCopy.motors
			let vibrators = nextCopy.vibrators
			let command = cmdMkr((tris[0].tuple, tris[1].tuple),
			                     (leds[0], leds[1], leds[2], leds[3]),
			                     (servos[0], servos[1], servos[2], servos[3]),
			                     (motors[0], motors[1]),
			                     (vibrators[0], vibrators[1]))
			
			self.sendData(data: command)
			self.lastWriteStart = DispatchTime.now()
			self.lastWriteWritten = false
			
			self.currentOutputState = nextCopy
			
			//For debugging
			let bytes = UnsafeMutableBufferPointer<UInt8>(start: UnsafeMutablePointer<UInt8>.allocate(capacity: 20), count: 19)
			let _ = command.copyBytes(to: bytes)
			print("Setting All: \(bytes.map({return $0}))")
		}
		else {
			if !self.lastWriteWritten {
				print("miss")
			}
		}
		
		self.writtenCondition.unlock()
	}
	
	func setAllOutputsToOff() -> Bool {
		self.writtenCondition.lock()
		self.nextOutputState = BBTHummingbirdOutputState()
		self.writtenCondition.unlock()
		
		return true
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
			
			if self.initialized {
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

//For HB renaming in beginInitialization
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


//For HB renaming in peripheral didUpdateValue
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
