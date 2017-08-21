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
	
	public static let minimumFirmware = "2.2a"
	public static let latestFirmware = "2.2b"
	
	//BLE adapter
	public static let deviceUUID    = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
	//UART Service
    static let SERVICE_UUID			= CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
	//sending
    static let TX_UUID				= CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
	//receiving
	static let RX_UUID				= CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    static let RX_CONFIG_UUID		= CBUUID(string: "00002902-0000-1000-8000-00805f9b34fb")
    var rx_line, tx_line: CBCharacteristic?
	
	static let sensorByteCount = 4
	private var lastSensorUpdate: [UInt8] = Array<UInt8>(repeating: 0, count: sensorByteCount)
	var sensorValues: [UInt8] {
		return lastSensorUpdate
	}
	
	private let initializationCompletion: ((BBTRobotBLEPeripheral) -> Void)?
	private var _initialized = false
	public var initialized: Bool {
		return self._initialized
	}
	
	
	//MARK: Variables to coordinate set all
	private var useSetall = true
	private var writtenCondition: NSCondition = NSCondition()
	
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
	
	
	private var initializingCondition = NSCondition()
	private var lineIn: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0]
	private var hardwareString = ""
	private var firmwareVersionString = ""
	
	//MARK: Variables for HB renaming
//	static let ADALE_COMMAND_MODE_TOGGLE = "+++\n"
//	static let ADALE_GET_MAC = "AT+BLEGETADDR\n"
//	static let ADALE_SET_NAME = "AT+GAPDEVNAME="
//	static let ADALE_RESET = "ATZ\n"
//	static let NAME_PREFIX = "HB"
//	var macStr: String? = nil
//	let macReplyLen = 17e
//	let macLen = 12
//	var oneOffTimer: Timer = Timer()
//	var resettingName = false
//	var gettingMAC = false
//	var commandMode = false
	
	override public var description: String {
		let gapName = self.peripheral.name ?? "Unknown"
		let name = BBTgetDeviceNameForGAPName(gapName)
		
		var updateDesc = ""
		if !self.useSetall {
			updateDesc = "\n\nThis Hummingbird needs to be updated. " +
				"See the link below: \n" +
				"http://www.hummingbirdkit.com/learning/installing-birdblox#BurnFirmware "
		}
		
		return
			"Hummingbird Peripheral\n" +
			"Name: \(name)\n" +
			"Bluetooth Name: \(gapName)\n" +
			"Hardware Version: \(self.hardwareString)\n" +
			"Firmware Version: \(self.firmwareVersionString)" +
			updateDesc
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
        self.sendData(data: BBTHummingbirdUtility.getPollStopCommand())
		Thread.sleep(forTimeInterval: 4) //make sure that the HB is booted up
		//Worked 4 of 5 times when at 3 seconds.
		
		let timeoutTime = Date(timeIntervalSinceNow: TimeInterval(7)) //seconds
		
		self.initializingCondition.lock()
		let oldLineIn = self.lineIn
		self.sendData(data: "G4".data(using: .utf8)!)
		
		//Wait until we get a response or until we timeout.
		//If we time out the verion will be 0.0, which is invalid.
		while (self.lineIn == oldLineIn && (Date().timeIntervalSince(timeoutTime) < 0)) {
			self.initializingCondition.wait(until: Date(timeIntervalSinceNow: 1))
		}
		let versionArray = self.lineIn
		
		
		self.hardwareString = String(versionArray[0]) + "." + String(versionArray[1])
		self.firmwareVersionString = String(versionArray[2]) + "." + String(versionArray[3]) +
			(String(bytes: [versionArray[4]], encoding: .ascii) ?? "")
		
		print(versionArray)
		print("end hi")
		self.initializingCondition.unlock()
		
		
		guard self.connected else {
			BLE_Manager.disconnect(byID: self.id)
			return
		}
		
		//If the firmware version is too low, then disconnect and inform the user.
		//Must be higher than 2.2b OR be 2.1i
		guard versionArray[2] >= 2 &&
				((versionArray[3] >= 2) || (versionArray[3] == 1 && versionArray[4] >= 105)) else {
			let _ = FrontendCallbackCenter.shared
				.robotFirmwareIncompatible(id: self.id, firmware: self.firmwareVersionString)
			
			BLE_Manager.disconnect(byID: self.id)
			return
		}
		
		//Old firmware, but still compatible
		if versionArray[3] == 1 && versionArray[4] >= 105 {
			let _ = FrontendCallbackCenter.shared.robotFirmwareStatus(id: self.id, status: "old")
			self.useSetall = false
		}
		
		
        Thread.sleep(forTimeInterval: 0.1)
		self.sendData(data: BBTHummingbirdUtility.getPollStartCommand())

//		DispatchQueue.main.async{
		if self.useSetall {
			self.syncTimer =
			Timer.scheduledTimer(timeInterval: self.syncInterval, target: self,
			                     selector: #selector(HummingbirdPeripheral.syncronizeOutputs),
			                     userInfo: nil, repeats: true)
			self.syncTimer.fire()
		}
//		}
		
		self._initialized = true
		print("Hummingbird initialized")
		if let completion = self.initializationCompletion {
			completion(self)
		}
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
		
		guard self.initialized else {
			self.initializingCondition.lock()
			print("hi")
			print(inData.debugDescription)
			inData.copyBytes(to: &self.lineIn, count: self.lineIn.count)
			self.initializingCondition.signal()
			self.initializingCondition.unlock()
			return
		}
		
        if characteristic.value!.count % 5 != 0 {
            return
        }
		
		//Assume it's sensor in data
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
		
//		print("did write")
		
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
		guard self.useSetall else {
			self.sendData(data: BBTHummingbirdUtility.getLEDCommand(UInt8(port),
																	intensity: intensity))
			return true
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
		guard self.useSetall else {
			let command = BBTHummingbirdUtility.getTriLEDCommand(UInt8(port),
			                                                     red_val: intensities.red,
			                                                     green_val: intensities.green,
			                                                     blue_val: intensities.blue)
			self.sendData(data: command)
			return true
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
		guard self.useSetall else {
			let command = BBTHummingbirdUtility.getVibrationCommand(UInt8(port),
																	intensity: intensity)
			self.sendData(data: command)
			return true
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
		guard self.useSetall else {
			let command = BBTHummingbirdUtility.getMotorCommand(UInt8(port),
			                                                        speed: Int(speed))
			self.sendData(data: command)
			return true
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
		guard self.useSetall else {
			let command = BBTHummingbirdUtility.getServoCommand(UInt8(port),
			                                                        angle: angle)
			self.sendData(data: command)
			return true
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
		let timeout = ((currentCPUTime - self.lastWriteStart.uptimeNanoseconds) >
						self.cacheTimeoutDuration)
		let shouldSync = changeOccurred || timeout
		
		
		if self.initialized && (self.lastWriteWritten || timeout)  && shouldSync {
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
			#if DEBUG
			let bytes = UnsafeMutableBufferPointer<UInt8>(
				start: UnsafeMutablePointer<UInt8>.allocate(capacity: 20), count: 19)
			let _ = command.copyBytes(to: bytes)
			print("Setting All: \(bytes.map({return $0}))")
			#endif
		}
		else {
			if !self.lastWriteWritten {
//				print("miss")
			}
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
