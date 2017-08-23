//
//  FinchPeripheral.swift
//  BirdBlox
//
//  Created by Jeremy Huang on 2017-08-02.
//  Copyright © 2017年 Birdbrain Technologies LLC. All rights reserved.
//

/* IMPORTANT
	This is a slightly modified version of the HB code in order to test the finch firmware.
	This is not acutual code for the Finch.
*/

import Foundation

import CoreBluetooth

class FinchPeripheral: NSObject, CBPeripheralDelegate, BBTRobotBLEPeripheral {
	public let peripheral: CBPeripheral
	public var id: String {
		return peripheral.identifier.uuidString
	}
	
	public static let type: BBTRobotType = .Finch
	
	private let BLE_Manager: BLECentralManager
	
	//BLE adapter
	public static let deviceUUID    = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
	//UART Service
	static let SERVICE_UUID			= CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
	//sending
	static let TX_UUID				= CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
	//receiving
	static let RX_UUID				= CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
	var rx_line, tx_line: CBCharacteristic?
	
	private var lastSensorUpdate: [UInt8] = Array<UInt8>(repeating: 0, count: 10)
	var sensorValues: [UInt8] {
		return lastSensorUpdate
	}
	
	private let initializationCompletion: ((BBTRobotBLEPeripheral) -> Void)?
	private var _initialized = false
	public var initialized: Bool {
		return self._initialized
	}
	
	
	//MARK: Variables to coordinate set all
	private var writtenCondition: NSCondition = NSCondition()
	
	//MARK: Variables write protected by writtenCondition
	private var currentOutputState: BBTHummingbirdOutputState
	public var nextOutputState: BBTHummingbirdOutputState
	var lastWriteWritten: Bool = false
	var lastWriteStart: DispatchTime = DispatchTime.now()
	//End variables write protected by writtenCondition
	private var syncTimer: Timer = Timer()
	let syncInterval = 0.017 //(60Hz)
	let cacheTimeoutDuration: UInt64 = 1 * 100_000_000 //units
	let waitRefreshTime = 0.5 //seconds
	
	
	private var initializingCondition = NSCondition()
	private var lineIn: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0]
	private var hardwareString = ""
	private var firmwareVersionString = ""
	
	
	override public var description: String {
		let gapName = self.peripheral.name ?? "Unknown"
		let name = BBTgetDeviceNameForGAPName(gapName)
		return
			"Hummingbird Peripheral\n" +
				"Name: \(name)\n" +
				"Bluetooth Name: \(gapName)\n" +
				"Hardware Version: \(self.hardwareString)\n" +
		"Firmware Version: \(self.firmwareVersionString)"
	}
	
	
	required init(peripheral: CBPeripheral, completion: ((BBTRobotBLEPeripheral) -> Void)? = nil){
		self.peripheral = peripheral
		self.BLE_Manager = BLECentralManager.shared
		
		self.currentOutputState = BBTHummingbirdOutputState()
		self.nextOutputState = BBTHummingbirdOutputState()
		
		self.initializationCompletion = completion
		
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
					DispatchQueue.main.async {
						self.initialize()
					}
					return
				}
			}
		}
	}
	
	private func initialize() {
		print("start init")
		//Get ourselves a fresh slate
		self.sendData(data: "BS".data(using: .ascii)!)
		Thread.sleep(forTimeInterval: 0.5) //
		self.sendData(data: "BG".data(using: .ascii)!)
		
		DispatchQueue.main.async {
			print("starting timer")
			self.syncTimer =
				Timer.scheduledTimer(timeInterval: self.syncInterval, target: self,
				                     selector: #selector(HummingbirdPeripheral.syncronizeOutputs),
				                     userInfo: nil, repeats: true)
			self.syncTimer.fire()
		}
		
		self._initialized = true
		print("Finch initialized")
		if let completion = self.initializationCompletion {
			completion(self)
		}
	}
	
	
	func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
	                error: Error?) {
		
		guard let inData = characteristic.value else {
			return
		}
		
		//Assume it's sensor in data
		inData.copyBytes(to: &self.lastSensorUpdate, count: 10)
	}
	
	/**
	* Called when we update a characteristic (when we write to the HB)
	*/
	func peripheral(_ peripheral: CBPeripheral,
	                didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
		if let error = error {
			NSLog("Unable to write to hummingbird due to error \(error)")
		}
		
		print("did write")
		
		//We successfully sent a command
		self.writtenCondition.lock()
		self.lastWriteWritten = true
		self.writtenCondition.signal()
		
		//		self.currentOutputState = self.nextOutputState.immutableCopy
		
		self.writtenCondition.unlock()
		//		print(self.lastWriteStart)
	}
	
	
	public func endOfLifeCleanup() -> Bool{
		//		self.sendData(data: BBTHummingbirdUtility.getPollStopCommand())
		self.syncTimer.invalidate()
		return true
	}
	
	public var connected: Bool {
		return peripheral.state == CBPeripheralState.connected
	}
	
	private func sendData(data: Data) {
		if self.connected {
			peripheral.writeValue(data, for: tx_line!, type: .withResponse)
			
			//			if self.commandMode {
			//				print("Sent command: " +
			//					(NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String))
			//			}
			//			else {
			////				print("Sent non-command mode message")
			//			}
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
		
		self.writtenCondition.lock()
		
		self.conditionHelper(condition: self.writtenCondition, holdLock: false,
		                     predicate: {
								self.nextOutputState.leds[i] == self.currentOutputState.leds[i]
		}, work: {
			self.nextOutputState.leds[i] = intensity
		})
		
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
	
	
	var allStr = "0,0,0,0,0,0,0,0,0,0,0,0,0,0"
	var lastStr = "0,0,0,0,0,0,0,0,0,0,0,0,0,0"
	
	func setAll(str: String) -> [UInt8] {
		self.writtenCondition.lock()
		self.allStr = str
		self.writtenCondition.unlock()
		return self.lastSensorUpdate
	}
	
	
	func syncronizeOutputs() {
		self.writtenCondition.lock()
		
		let nextCopy = allStr
		
		let changeOccurred = !(nextCopy == lastStr)
		let currentCPUTime = DispatchTime.now().uptimeNanoseconds
		let timeout = ((currentCPUTime - self.lastWriteStart.uptimeNanoseconds) >
			self.cacheTimeoutDuration)
		let shouldSync = changeOccurred || timeout
		
		if self.initialized && (self.lastWriteWritten || timeout)  && shouldSync {
				
			let strs = ("75," + self.allStr).components(separatedBy: ",")
			let bytes = strs.map({UInt8($0, radix: 16)!})
			
			let command = Data(bytes: bytes)
			self.sendData(data: command)
			self.lastWriteStart = DispatchTime.now()
			self.lastWriteWritten = false
			
			lastStr = allStr
			
			//For debugging
			print("Setting All: \(bytes.map({return $0}))")
		}
		
		self.writtenCondition.unlock()
	}
	
	func setAllOutputsToOff() -> Bool {
		//Sending an ASCII capital X should do the same thing.
		//Useful for legacy firmware
		
		self.writtenCondition.lock()
		self.nextOutputState = BBTHummingbirdOutputState()
		self.writtenCondition.unlock()
		
		return true
	}
}
