//
//  BLECentralManager.swift
//  BirdBlox
//
//  Created by birdbrain on 3/23/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//
import Foundation
import CoreBluetooth

// This wraps the method of getting the state in iOS versions prior to iOS10
extension CBCentralManager {
	internal var centralManagerState: CBCentralManagerState  {
		get {
			return CBCentralManagerState(rawValue: state.rawValue) ?? .unknown
		}
	}
}


class BLECentralManager: NSObject, CBCentralManagerDelegate {
	
	enum BLECentralManagerScanState {
		case notScanning
		case searchingScan
		case countingScan
	}
	
	public static let shared: BLECentralManager = BLECentralManager()
	
	private let centralManager: CBCentralManager
	
	public var scanState: BLECentralManagerScanState
	
	private var discoveredPeripherals: [String: CBPeripheral]
	private var connectedPeripherals: [String: CBPeripheral]
	private var connectedRobots: [String: BBTRobotBLEPeripheral]
	private var oughtToBeConnected: [String: (peripheral: CBPeripheral, type: BBTRobotType)]
	
	private var discoverTimer: Timer
	private static let scanDuration = TimeInterval(30) //seconds
	
	
	var deviceCount: UInt
	
	override init() {
		
		self.discoveredPeripherals = [String: CBPeripheral]()
		self.scanState = .notScanning
		self.discoverTimer = Timer()
		self.deviceCount = 0
		
		self.connectedRobots = Dictionary()
		self.connectedPeripherals = Dictionary()
		
		let centralQueue = DispatchQueue(label: "com.BirdBrainTech.BLE", attributes: [])
		self.centralManager = CBCentralManager(delegate: self, queue: centralQueue)
		
		super.init();
	}
	
	public var isScanning: Bool {
		return self.scanState == .searchingScan
	}
	
	public var devicesInVicinity: UInt {
		return self.deviceCount
	}
	
	public func startScan(serviceUUIDs: [CBUUID]) {
		if self.scanState == .countingScan {
			self.stopScan()
		}
		if !self.isScanning && (self.centralManager.centralManagerState == .poweredOn) {
			self.discoveredPeripherals.removeAll()
			centralManager.scanForPeripherals(withServices: serviceUUIDs, options: nil)
			discoverTimer = Timer.scheduledTimer(timeInterval: BLECentralManager.scanDuration,
			                                     target: self,
			                                     selector: #selector(BLECentralManager.stopScan),
			                                     userInfo: nil, repeats: false)
			self.scanState = .searchingScan
			NSLog("Stated bluetooth scan")
		}
	}
	
	public func startCountingScan() {
		self.deviceCount = 0
		self.centralManager.scanForPeripherals(withServices: nil, options: nil)
		self.scanState = .countingScan
		if #available(iOS 10.0, *) {
			self.discoverTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: false) {
				t in self.stopScan()
			}
		} else {
			discoverTimer = Timer.scheduledTimer(timeInterval: TimeInterval(120), target: self,
			                                     selector: #selector(BLECentralManager.stopScan),
			                                     userInfo: nil, repeats: false)
		}
	}
	
	public func stopScan() {
		if isScanning {
			centralManager.stopScan()
			self.scanState = .notScanning
			discoverTimer.invalidate()
			NSLog("Stopped bluetooth scan")
		}
	}
	
	public var foundDevices: [String: CBPeripheral] {
		return self.discoveredPeripherals
	}
	
	
	/**
	* If a device is discovered, it is given a unique name and added to our
	* discovered list. If the device was connected in this session and had
	* lost connection, it is automatically connected to again
	*/
	func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
	                    advertisementData: [String : Any], rssi RSSI: NSNumber) {
		switch self.scanState {
		case .countingScan:
			self.deviceCount += 1
		case .searchingScan:
			self.discoveredPeripherals[peripheral.identifier.uuidString] = peripheral
		default:
			return
		}
	}
	
	/**
	* If we connected to a peripheral, we add it to our services and stop
	* discovering new devices
	*/
	func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
		if self.discoveredPeripherals.keys.contains(peripheral.name!) {
			self.discoveredPeripherals.removeValue(forKey: peripheral.name!)
		}
		
		// If we are trying to connect to the flutter, then add it. 
		// If we are not supposed to be connected to the flutter, then disconnect from it
		// If we are already connected, do nothing.
		if self.connectingFlutters.contains(peripheral) {
			let id = peripheral.identifier.uuidString
			self.connectedFlutters[id] = FlutterPeripheral(peripheral: peripheral)
			self.connectingFlutters.remove(peripheral)
			let _ = FrontendCallbackCenter.shared.robotUpdateStatus(id: id, connected: true)
		}
		else if let connectedCompletion = self.hbConnectedCompletions[peripheral] {
			connectedCompletion()
			let id = peripheral.identifier.uuidString
			let _ = FrontendCallbackCenter.shared.robotUpdateStatus(id: id, connected: true)
		}
		else if !self.connectedFlutters.contains(where:
			{ (k, v) in v.peripheral.identifier == peripheral.identifier }) {
			
			self.disconnect(peripheral: peripheral)
		}
	}
	
	/**
	* If we disconnected from a peripheral
	*/
	func centralManager(_ central: CBCentralManager,
	                    didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
		var errorStr: String = "No error"
		if let error = error {
			errorStr = "\(error)"
		}
		print("error disconnecting \(peripheral),  \(errorStr)")
		
		let id = peripheral.identifier.uuidString
		self.connectedPeripherals.removeValue(forKey: id)
		self.connectedRobots.removeValue(forKey: id)
		let _ = FrontendCallbackCenter.shared.robotUpdateStatus(id: id, connected: false)
	}
	
	/**
	* We failed to connect to a peripheral, we could notify the user here?
	*/
	func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral,
	                    error: Error?) {
		var errorStr: String = "No error"
		if let error = error {
			errorStr = "\(error)"
		}
		print("Failed to connect to peripheral \(peripheral),  \(errorStr)")
	}
	
	func centralManagerDidUpdateState(_ central: CBCentralManager) {
		
		switch (central.centralManagerState) {
		case CBCentralManagerState.poweredOff:
			break
			
		case CBCentralManagerState.unauthorized:
			// Indicate to user that the iOS device does not support BLE.
			break
			
		case CBCentralManagerState.unknown:
			// Wait for another event
			break
			
		case CBCentralManagerState.poweredOn:
			//startScanning
			break
			
		case CBCentralManagerState.resetting:
			//nothing to do
			break
			
		case CBCentralManagerState.unsupported:
			break
		}
	}
	
	func disconnect(peripheral: CBPeripheral) {
		self.oughtToBeConnected.removeValue(forKey: peripheral.identifier.uuidString)
		centralManager.cancelPeripheralConnection(peripheral)
	}
	
	func connectTo(peripheral: CBPeripheral, ofType type: BBTRobotType) {
		let options = [CBConnectPeripheralOptionNotifyOnDisconnectionKey: NSNumber(value: true)]
		self.centralManager.connect(peripheral, options: options)
		
		let idString = peripheral.identifier.uuidString
		self.discoveredPeripherals.removeValue(forKey: idString)
		self.oughtToBeConnected[idString] = (peripheral: peripheral, type: type)
	}
}
