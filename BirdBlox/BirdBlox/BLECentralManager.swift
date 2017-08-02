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
	
	private var centralManager: CBCentralManager
	private let centralQueue: DispatchQueue
	
	public var scanState: BLECentralManagerScanState
	
	private var _discoveredPeripheralsSeqeuntial: [CBPeripheral]
	private var discoveredPeripherals: [String: CBPeripheral]
	private var connectedPeripherals: [String: CBPeripheral]
	private var connectedRobots: [String: BBTRobotBLEPeripheral]
	private var oughtToBeConnected: [String: (peripheral: CBPeripheral, type: BBTRobotType)]
	
	private var discoverTimer: Timer
	private static let scanDuration = TimeInterval(30) //seconds
	
	private var currentlyConnecting: Any
	
	
	var deviceCount: UInt
	
	override init() {
		
		self.discoveredPeripherals = [String: CBPeripheral]()
		self.scanState = .notScanning
		self.discoverTimer = Timer()
		self.deviceCount = 0
		
		self.connectedRobots = Dictionary()
		self.connectedPeripherals = Dictionary()
		self._discoveredPeripheralsSeqeuntial = Array()
		self.oughtToBeConnected = Dictionary()
		
		self.centralQueue = DispatchQueue(label: "ble", attributes: [])
		self.centralManager = CBCentralManager(delegate: nil, queue: centralQueue)
		
		self.currentlyConnecting = 5
		
		super.init()
		
		self.centralManager.delegate = self
	}
	
	//MARK: Scanning
	public var isScanning: Bool {
		return self.scanState == .searchingScan
	}
	
	public var devicesInVicinity: UInt {
		return self.deviceCount
	}
	
	private var scanStoppedBlock: (() -> Void)? = nil
	private var robotDiscoveredBlock: (([CBPeripheral]) -> Void)? = nil
	
	public func startScan(serviceUUIDs: [CBUUID],
	                      updateDiscovered: (([CBPeripheral]) -> Void)? = nil,
	                      scanEnded: (() -> Void)? = nil) {
		
		self.stopScan()
		
		guard !self.isScanning && (self.centralManager.centralManagerState == .poweredOn) else {
			return
		}
		
		self.discoveredPeripherals.removeAll()
		self._discoveredPeripheralsSeqeuntial = []
		
		self.robotDiscoveredBlock = updateDiscovered
		self.scanStoppedBlock = scanEnded
		
		centralManager.scanForPeripherals(withServices: serviceUUIDs, options: nil)
		discoverTimer = Timer.scheduledTimer(timeInterval: BLECentralManager.scanDuration,
		                                     target: self,
		                                     selector: #selector(BLECentralManager.stopScan),
		                                     userInfo: nil, repeats: false)
		self.scanState = .searchingScan
		NSLog("Stated bluetooth scan")
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
			
			if let se = self.scanStoppedBlock {
				se()
			}
		}
	}
	
	public var foundDevices: [CBPeripheral] {
		return self._discoveredPeripheralsSeqeuntial
	}
	
	//MARK: Connected robots
	public func isRobotWithIDConnected(_ id: String) -> Bool {
		return self.connectedRobots.keys.contains(id) && self.connectedRobots[id]!.connected
	}
	
	public func robotForID(_ id: String) -> BBTRobotBLEPeripheral? {
		return self.connectedRobots[id]
	}
	
	public func forEachConnectedRobots(do action: ((BBTRobotBLEPeripheral) -> Void)) {
		for robot in self.connectedRobots.values {
			action(robot)
		}
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
			let id = peripheral.identifier.uuidString
			if self.discoveredPeripherals.keys.contains(id) {
				self.discoveredPeripherals[id] = peripheral
			} else {
				self.discoveredPeripherals[id] = peripheral
				self._discoveredPeripheralsSeqeuntial.append(peripheral)
			}
			
			if let type = self.oughtToBeConnected[id]?.type {
				let _ = self.connectToRobot(byID: id, ofType: type)
			}
			
			if let rd = self.robotDiscoveredBlock {
				rd(self.foundDevices)
			}
			
		default:
			return
		}
	}
	
	/**
	* If we connected to a peripheral, we add it to our list and begin initializing it's robot
	*/
	func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
		let id = peripheral.identifier.uuidString
		self.connectedPeripherals[id] = peripheral
		
		guard let type = self.oughtToBeConnected[id]?.type else {
			print("Peripheral that ought not to be connected was connected")
			self.disconnect(byID: id)
			return
		}
		
		var robotInit: (CBPeripheral, ((BBTRobotBLEPeripheral) -> Void)?) -> BBTRobotBLEPeripheral
		switch type {
		case .Hummingbird:
			robotInit = HummingbirdPeripheral.init
		case .Flutter:
			robotInit = FlutterPeripheral.init
		case .Finch:
			robotInit = FinchPeripheral.init
		default:
			robotInit = HummingbirdPeripheral.init
		}
		
		self.currentlyConnecting = robotInit(peripheral, {rbt in
			let id = rbt.peripheral.identifier.uuidString
			if self.oughtToBeConnected.keys.contains(id) {
				self.connectedRobots[id] = rbt
				let _ = FrontendCallbackCenter.shared.robotUpdateStatus(id: id, connected: true)
				self.currentlyConnecting = 5
			} else {
//				self.disconnect(byID: id)
			}
		})
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
	
	func disconnect(byID id: String) {
		print("disconnect running")
		guard self.oughtToBeConnected.keys.contains(id) ||
			self.connectedPeripherals.keys.contains(id) else {
			return
		}
		
		var peripheral: CBPeripheral
		if self.oughtToBeConnected.keys.contains(id) {
			peripheral = self.oughtToBeConnected[id]!.peripheral
		} else {
			peripheral = self.connectedPeripherals[id]!
		}
		
		if let robot = self.connectedRobots[id] {
			let _ = robot.endOfLifeCleanup()
		}
		
		self.oughtToBeConnected.removeValue(forKey: id)
		
		
		centralManager.cancelPeripheralConnection(peripheral)
		self.currentlyConnecting = 5
		
		print("disconnect running")
	}
	
	//Returns false if no robot with id is in the discovered list
	//Implicitly stops the scan
	func connectToRobot(byID id: String, ofType type: BBTRobotType) -> Bool {
		guard let peripheral = self.discoveredPeripherals[id] else {
			return false
		}
		
		let idString = peripheral.identifier.uuidString
		self.discoveredPeripherals.removeValue(forKey: idString)
		self.oughtToBeConnected[idString] = (peripheral: peripheral, type: type)
//		self.connectedPeripherals[idString] = peripheral
		
		let options = [CBConnectPeripheralOptionNotifyOnDisconnectionKey: NSNumber(value: true)]
		self.centralManager.connect(peripheral, options: options)
		
		self.stopScan()
		
		return true
	}
}
