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
	
	private var _discoveredPeripheralsSeqeuntial: [(CBPeripheral, String, BBTRobotType)]
	private var discoveredPeripherals: [String: CBPeripheral]
	private var connectedPeripherals: [String: CBPeripheral]
	private var connectedRobots: [String: BBTRobotBLEPeripheral]
    private var oughtToBeConnected: [String: (peripheral: CBPeripheral, type: BBTRobotType, connectAttempts: Int)]
    private var attemptingConnection: [String]
	
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
        self.attemptingConnection = Array()
		
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
	private var robotDiscoveredBlock: (([(CBPeripheral, String, BBTRobotType)]) -> Void)? = nil
	
	public func startScan(serviceUUIDs: [CBUUID],
	                      updateDiscovered: (([(CBPeripheral, String, BBTRobotType)]) -> Void)? = nil,
	                      scanEnded: (() -> Void)? = nil) {
		
        //Stop any scanning that is already occuring. No need to notify the frontend or do anything
        // else at this time - scanning will resume shortly.
        self.scanStoppedBlock = nil
		self.stopScan()
		
		guard !self.isScanning && (self.centralManager.centralManagerState == .poweredOn) else {
			return
		}
		
		self.discoveredPeripherals.removeAll()
		self._discoveredPeripheralsSeqeuntial = []
		
		self.robotDiscoveredBlock = updateDiscovered
		self.scanStoppedBlock = scanEnded
		
        let options = [CBCentralManagerScanOptionAllowDuplicatesKey: true]
		centralManager.scanForPeripherals(withServices: serviceUUIDs, options: options)
		discoverTimer = Timer.scheduledTimer(timeInterval: BLECentralManager.scanDuration,
		                                     target: self,
		                                     selector: #selector(BLECentralManager.stopScan),
		                                     userInfo: nil, repeats: false)
		self.scanState = .searchingScan
		NSLog("Started bluetooth scan")
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
	
	public var foundDevices: [(CBPeripheral, String, BBTRobotType)] {
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
	
    //MARK: Central Manager Delegate methods
	
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
            guard let robotType = BBTRobotType.fromString(advertisementData["kCBAdvDataLocalName"] as? String ?? peripheral.name ?? "unknown") else {
                NSLog("Could not determine type of peripheral with id \(id)")
                return
            }
            
            //check to see if we are already trying to connect to this one
            if self.attemptingConnection.contains(id) { return }
            
			if self.discoveredPeripherals.keys.contains(id) {
				self.discoveredPeripherals[id] = peripheral
			} else {
				self.discoveredPeripherals[id] = peripheral
				self._discoveredPeripheralsSeqeuntial.append((peripheral, RSSI.stringValue, robotType))
			}
			
			if let type = self.oughtToBeConnected[id]?.type {
                if type != robotType {
                    print("Type missmatch! \(type.description) ne \(robotType.description)")
                    self.oughtToBeConnected[id]?.type = robotType
                }
                print("Found a robot that ought to be connected! \(peripheral.name ?? "unknown") \(connectedPeripherals.keys.contains(id)) \(connectedRobots.keys.contains(id)) \(currentlyConnecting) \(self.attemptingConnection.contains(id)) \(self.attemptingConnection.count)")
                
                let _ = self.connectToRobot(byID: id, ofType: robotType)
			}
			
			if let rd = self.robotDiscoveredBlock {
				rd(self.foundDevices)
			}
			
            //print("Advertised name: \(advertisementData["kCBAdvDataLocalName"] ?? "unknown") Robot type: \(robotType.description)")
            
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
		
		guard let type = self.oughtToBeConnected[id]?.type, let attempts = self.oughtToBeConnected[id]?.connectAttempts else {
			print("Peripheral that ought not to be connected was connected")
			self.disconnect(byID: id)
			return
		}
		
        print("did connect \(peripheral.name ?? "unknown") of type: \(type.description)")
		self.currentlyConnecting = BBTRobotBLEPeripheral.init(peripheral, type, attempts, {rbt in
			let id = rbt.peripheral.identifier.uuidString
			if self.oughtToBeConnected.keys.contains(id) {
				self.connectedRobots[id] = rbt
				let _ = FrontendCallbackCenter.shared.robotUpdateStatus(id: id, connected: true)
                if let bs = rbt.batteryStatus?.rawValue {
                    let _ = FrontendCallbackCenter.shared.robotUpdateBattery(id: id, batteryStatus: bs)
                }
				self.currentlyConnecting = 5
                self.attemptingConnection = self.attemptingConnection.filter{ $0 != id }
            } else { //TODO: is this where we get robots connected in the background?? check currentlyConnecting somewhere.
                NSLog("A robot (\(rbt.name)) was just initialized that is not in the oughtToBeConnected list.")
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
		if let robot = self.connectedRobots[id] {
			let _ = robot.endOfLifeCleanup()
		}
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
	
    //MARK: Connect/disconnect robot
    
	func disconnect(byID id: String) {
		print("disconnect running")
        /*
		guard self.oughtToBeConnected.keys.contains(id) ||
			self.connectedPeripherals.keys.contains(id) else {
			return
		}
		
		var peripheral: CBPeripheral
		if self.oughtToBeConnected.keys.contains(id) {
			peripheral = self.oughtToBeConnected[id]!.peripheral
		} else {
			peripheral = self.connectedPeripherals[id]!
		}*/
		
        guard let peripheral = self.oughtToBeConnected[id]?.peripheral ?? self.connectedPeripherals[id] else {
            NSLog("Could not find peripheral to disconnect.")
            return
        }
        
        if let robot = self.connectedRobots[id] {
            NSLog("In the process of disconnecting \(robot.name).")
        } else {
            NSLog("Could not find robot for \(id) during disconnect.")
        }
		self.oughtToBeConnected.removeValue(forKey: id)
		
		
		centralManager.cancelPeripheralConnection(peripheral)
		self.currentlyConnecting = 5
		
		print("disconnect done")
	}
	
	//Returns false if no robot with id is in the discovered list
	//Implicitly stops the scan
	func connectToRobot(byID id: String, ofType type: BBTRobotType) -> Bool {
        
		guard let peripheral = self.discoveredPeripherals[id] else {
            NSLog("Failed to find the peripheral we are trying to connect to...")
			return false
		}
        self.attemptingConnection.append(id)
        //self.discoveredPeripherals.removeValue(forKey: id) //TODO: Does this do anything?
        
		Thread.sleep(forTimeInterval: 3.0) //make sure that the HB is booted up
		
        connectToRobot(byPeripheral: peripheral, ofType: type)
		
        self.stopScan()
		
		return true
	}
    
    func connectToRobot(byPeripheral peripheral: CBPeripheral, ofType type: BBTRobotType) {
        let id = peripheral.identifier.uuidString
        
        if self.oughtToBeConnected.keys.contains(id) {
            self.oughtToBeConnected[id]?.connectAttempts += 1
        } else {
            self.oughtToBeConnected[id] = (peripheral: peripheral, type: type, 0)
        }
        print("Connect to robot. \(peripheral.name ?? "unknown") \(oughtToBeConnected)")
        
        let options = [CBConnectPeripheralOptionNotifyOnDisconnectionKey: NSNumber(value: true)]
        self.centralManager.connect(peripheral, options: options)
    }
}
