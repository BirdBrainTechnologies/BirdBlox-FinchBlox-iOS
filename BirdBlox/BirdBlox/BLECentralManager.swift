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

	public static let manager: BLECentralManager = BLECentralManager()
    
	var centralManager: CBCentralManager!
	var discoveredDevices: [String: CBPeripheral]
	var isScanning: Bool
	var discoverTimer: Timer
	var waitingToConnect: [String]
    
    override init() {
		
		self.discoveredDevices = [String: CBPeripheral]()
		self.isScanning = false
		self.discoverTimer = Timer()
		self.waitingToConnect = Array()
		
		super.init();
		
        let centralQueue = DispatchQueue(label: "com.BirdBrainTech", attributes: [])
        centralManager = CBCentralManager(delegate: self, queue: centralQueue)
    }
    
    func startScan(serviceUUIDs: [CBUUID]) {
        if !isScanning {
            isScanning = true
            discoveredDevices.removeAll()
            centralManager.scanForPeripherals(withServices: serviceUUIDs, options: nil)
            discoverTimer = Timer.scheduledTimer(timeInterval: TimeInterval(30), target: self,
                                                 selector: #selector(BLECentralManager.stopScan),
												 userInfo: nil, repeats: false)
			NSLog("Stated bluetooth scan")
        }
    }
    func stopScan() {
        if isScanning {
            centralManager.stopScan()
            isScanning = false
            discoverTimer.invalidate()
			NSLog("Stopped bluetooth scan")
        }
    }
	
	var foundDevices: [String: CBPeripheral] {
		return self.discoveredDevices
	}
	
	func getDeviceNameForGAPName(_ gap: String) -> String {
		if let kidName = BBTKidNameFromMacSuffix(gap) {
			return kidName
		}
		
		//TODO: If the GAP name is the default hummingbird name, then grab the MAC address,
		//set the GAP name to "HB\(last 5 of MAC)", and use that to generate a kid name
		
		return gap
	}

	
    /**
     * If a device is discovered, it is given a unique name and added to our
     * discovered list. If the device was connected in this session and had
     * lost connection, it is automatically connected to again
     */
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi RSSI: NSNumber) {
        discoveredDevices[getDeviceNameForGAPName(peripheral.identifier.uuidString)] = peripheral
    }
    
    /**
     * If we connected to a peripheral, we add it to our services and stop
     * discovering new devices
     */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if discoveredDevices.keys.contains(peripheral.name!) {
            discoveredDevices.removeValue(forKey: peripheral.name!)
        }
        if waitingToConnect.contains(peripheral.name!) {
            waitingToConnect.remove(at: waitingToConnect.index(of: peripheral.name!)!)
        }
    }
    
    /**
     * If we disconnected from a peripheral
     */
    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    
        
    }
    /**
     * We failed to connect to a peripheral, we could notify the user here?
     */
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {

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
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    func connectToHummingbird(peripheral: CBPeripheral) -> HummingbirdPeripheral {
        waitingToConnect.append(peripheral.name!)
        centralManager?.connect(peripheral,
                                options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey:
								NSNumber(value: true as Bool)])
        while(waitingToConnect.contains(peripheral.name!)) {
            sched_yield()
        }
        return HummingbirdPeripheral(peripheral: peripheral)
    }
    
    func connectToFlutter(peripheral: CBPeripheral) -> FlutterPeripheral {
        waitingToConnect.append(peripheral.name!)
        centralManager?.connect(peripheral,
                                options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey:
								NSNumber(value: true as Bool)])
        while(waitingToConnect.contains(peripheral.name!)) {
            sched_yield()
        }
        return FlutterPeripheral(peripheral: peripheral)
    }
}
