//
//  BluetoothDiscovery.swift
//  HummingbirdLibrary
//
//  Created by birdbrain on 5/26/15.
//  Copyright (c) 2015 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import CoreBluetooth

private let sharedBluetoothDiscovery = BluetoothDiscovery()

class BluetoothDiscovery: NSObject, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager?
    
    private var connectNames = [CBPeripheral: String]()
    private var allNames = [CBPeripheral: String]()
    private var nameCount = [String: UInt]()
    private var discoveredDevices = [String: CBPeripheral]()
    private var isScanning = false
    private var discoverTimer: NSTimer = NSTimer()
    
    
    var serviceBLE: BluetoothService = BluetoothService()
    
    override init(){
        super.init();
        let centralQueue = dispatch_queue_create("com.BirdBrainTech", DISPATCH_QUEUE_SERIAL)
        centralManager = CBCentralManager(delegate: self, queue: centralQueue)
    }
    
    internal static func getBLEDiscovery() -> BluetoothDiscovery{
        return sharedBluetoothDiscovery
    }
    
    func startScan(){
        if !isScanning {
            if let central = centralManager{
                discoveredDevices = [String: CBPeripheral]()
                NSLog("looking for devices with a service of UUID: " + BLEServiceUUID.UUIDString)
                central.scanForPeripheralsWithServices([BLEServiceUUID], options: nil)
                isScanning = true
                discoverTimer = NSTimer.scheduledTimerWithTimeInterval(NSTimeInterval(30), target: self, selector: #selector(BluetoothDiscovery.stopScan), userInfo: nil, repeats: false)
                //central.scanForPeripheralsWithServices(nil, options: nil)
            } else {
                NSLog("Failed to acquire central manager")
            }
        }
    }
    
    func stopScan() {
        if isScanning {
            NSLog("Stopping scan")
            if let central = centralManager{
                central.stopScan()
                isScanning = false
                discoverTimer.invalidate()
            }
        } else {
            NSLog("Can't stop scanning because not currently scanning")
        }
    }
    
    func restartScan(){
        stopScan()
        startScan()
    }
    
    
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        if((peripheral.name == nil) || (peripheral.name == "")){
            return
        }
        var nameString: NSString = NSString()
        var localName: String
        if let oldname = allNames[peripheral] {
            localName = oldname
        } else {
            if let ns: AnyObject = advertisementData[CBAdvertisementDataLocalNameKey] as? NSString{
                nameString = ns as! NSString
            }
            else{
                nameString = peripheral.name!
            }
            localName = String(nameString)
            if Array(nameCount.keys.lazy).contains(nameString as String) {
                nameCount[nameString as String]! += UInt(1)
                localName = localName + String(nameCount[nameString as String]!)
            } else {
                nameCount[nameString as String] = 1
            }
            allNames[peripheral] = localName
        }
            dbg_print("Found a device: " + localName)
            if(!discoveredDevices.values.contains(peripheral)){
                discoveredDevices[localName] = peripheral
            }
            if(Array(connectNames.keys.lazy).contains(peripheral)){
                NSLog("Attempting to reconnect to old device!")
                connectToPeripheral(peripheral, name: localName)
                return
            }
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        let name = connectNames[peripheral]!
        NSLog("connected to device: " + name)
        self.serviceBLE.addPeripheral(peripheral, name: name)
        stopScan()
    }
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        NSLog("Disconnected from a peripheral!!!")
        self.serviceBLE.removePeripheral(peripheral)
        self.startScan()
    }
    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        NSLog("Failed to connect to a peripheral!!!")
        self.restartScan()
    }
    
    func centralManagerDidUpdateState(central: CBCentralManager) {
        switch (central.state) {
        case CBCentralManagerState.PoweredOff:
            //self.clearDevices
            break
            
        case CBCentralManagerState.Unauthorized:
            // Indicate to user that the iOS device does not support BLE.
            break
            
        case CBCentralManagerState.Unknown:
            // Wait for another event
            break
            
        case CBCentralManagerState.PoweredOn:
            //startScanning
            self.startScan()
            break
            
        case CBCentralManagerState.Resetting:
            //nothing to do
            break
            
        case CBCentralManagerState.Unsupported:
            break
        }
        
    }
    
    func connectToPeripheral(peripheral: CBPeripheral, name: String){
        centralManager!.cancelPeripheralConnection(peripheral)
        connectNames[peripheral] = name
        NSLog("Calling connect to peripheral on " + name)
        centralManager!.connectPeripheral(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: NSNumber(bool:true)])
        discoveredDevices.removeValueForKey(name)
    }
    
    func disconnectFromPeripheral(peripheral: CBPeripheral) -> Bool {
        centralManager?.cancelPeripheralConnection(peripheral)
        connectNames.removeValueForKey(peripheral)
        return true
    }
    func disconnectFromPeripheralbyName(name: String) -> Bool {
        for (peripheral, pName) in connectNames {
            if pName == name {
                disconnectFromPeripheral(peripheral)
                return true
            }
        }
        NSLog("Failed to disconnect because peripheral of name: " + name + " count not be found. Known names are: " + connectNames.values.joinWithSeparator(", "))
        return false
    }
    func renamePeripheral(peripheral: CBPeripheral, newName: String) -> String{
        var localName = String(newName)
        if Array(nameCount.keys.lazy).contains(newName as String) {
            nameCount[newName as String]! += UInt(1)
            localName = localName + String(nameCount[newName as String]!)
        } else {
            nameCount[newName as String] = 1
        }
        let oldName = allNames[peripheral]
        if connectNames[peripheral] != nil {
            connectNames[peripheral] = localName
        }
        if allNames[peripheral] != nil {
            allNames[peripheral] = localName
        }
        if let validOldName = oldName {
            if discoveredDevices[validOldName] == peripheral {
                discoveredDevices.removeValueForKey(validOldName)
                discoveredDevices[localName] = peripheral
            }
        }
        serviceBLE.renamePeripheral(peripheral, newName: localName)
        return localName
    }
    
    func renamePeripheralbyName(oldName: String, newName: String) -> String?{
        var peripheral: CBPeripheral?
        for (periph, pName) in connectNames {
            if pName == oldName {
                peripheral = periph
            }
        }
        if let validPeripheral = peripheral {
            return renamePeripheral(validPeripheral, newName: newName)
        }
        return nil
        
    }
    
    func getDiscovered() -> [String:CBPeripheral] {
        return discoveredDevices
    }
    
    func getConnected() -> [String] {
        return Array(connectNames.values.lazy)
    }
    
    func getServiceNames() -> [String] {
        return serviceBLE.getDeviceNames()
    }
    func getAllNames() -> [String] {
        return Array(allNames.values.lazy)
    }
    
    func removeConnected(name: String) {
        var peripheral: CBPeripheral?
        for (periph, pName) in connectNames {
            if pName == name {
                peripheral = periph
            }
        }
        if let validPeripheral = peripheral{
            connectNames.removeValueForKey(validPeripheral)
        }
    }
}