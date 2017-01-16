//
//  BluetoothDiscovery.swift
//  HummingbirdLibrary
//
// This file is responsible for discovering hummingbirds, connecting to them and
// disconnecting from them. It also stores various lists to keep track of all 
// the hummingbirds that have been connected. This class follows a singleton 
// pattern
//
//  Created by birdbrain on 5/26/15.
//  Copyright (c) 2015 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import CoreBluetooth

private let sharedBluetoothDiscovery = BluetoothDiscovery()

class BluetoothDiscovery: NSObject, CBCentralManagerDelegate {
    fileprivate var centralManager: CBCentralManager?
    
    //This is a mapping of the devices that are currently connected to their
    //names
    fileprivate var connectNames = [CBPeripheral: String]()
    //This is a mapping of all devices that have ever connected in this session
    //to their names
    fileprivate var allNames = [CBPeripheral: String]()
    //This maps a name to how many devices have had the same name
    //This is to prevent having duplicate names
    fileprivate var nameCount = [String: UInt]()
    //This maps the names of devices that have been discovered (not connected to)
    //to the actual devices
    fileprivate var discoveredDevices = [String: CBPeripheral]()
    //Keeps track of if we are currently discovering new devices
    fileprivate var isScanning = false
    fileprivate var discoverTimer: Timer = Timer()
    
    //This is our one Bluetooth service, it manages all the devices
    //that we are conencted to
    var serviceBLE: BluetoothService = BluetoothService()
    
    override init(){
        super.init();
        let centralQueue = DispatchQueue(label: "com.BirdBrainTech", attributes: [])
        centralManager = CBCentralManager(delegate: self, queue: centralQueue)
    }
    
    internal static func getBLEDiscovery() -> BluetoothDiscovery{
        return sharedBluetoothDiscovery
    }
    
    func startScan(){
        if !isScanning {
            if let central = centralManager{
                discoveredDevices = [String: CBPeripheral]()
                NSLog("looking for devices with a service of UUID: " + BLEServiceUUID.uuidString)
                central.scanForPeripherals(withServices: [BLEServiceUUID], options: nil)
                isScanning = true
                discoverTimer = Timer.scheduledTimer(timeInterval: TimeInterval(30), target: self, selector: #selector(BluetoothDiscovery.stopScan), userInfo: nil, repeats: false)
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
    
    
    /**
     * If a device is discovered, it is given a unique name and added to our
     * discovered list. If the device was connected in this session and had
     * lost connection, it is automatically connected to again
     */
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
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
                nameString = peripheral.name! as NSString
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
    /**
     * If we connected to a peripheral, we add it to our services and stop
     * discovering new devices
     */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let name = connectNames[peripheral]!
        NSLog("connected to device: " + name)
        self.serviceBLE.addPeripheral(peripheral, name: name)
        stopScan()
    }
    /**
     * If we disconnected from a peripheral, we remove it from our services and
     * start discovering new devices
     */
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        NSLog("Disconnected from a peripheral!!!" + allNames[peripheral]!)
        self.serviceBLE.removePeripheral(peripheral)
        self.startScan()
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        NSLog("Failed to connect to a peripheral!!!")
        self.restartScan()
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch (central.state) {
        case CBCentralManagerState.poweredOff:
            //self.clearDevices
            break
            
        case CBCentralManagerState.unauthorized:
            // Indicate to user that the iOS device does not support BLE.
            break
            
        case CBCentralManagerState.unknown:
            // Wait for another event
            break
            
        case CBCentralManagerState.poweredOn:
            //startScanning
            self.startScan()
            break
            
        case CBCentralManagerState.resetting:
            //nothing to do
            break
            
        case CBCentralManagerState.unsupported:
            break
        }
        
    }
    /**
     * To connected to a peripheral, we add it to our list of connected names, 
     * initiate a connection to it, then remove it from our discovered devices
     * list
     */
    func connectToPeripheral(_ peripheral: CBPeripheral, name: String){
        centralManager!.cancelPeripheralConnection(peripheral)
        connectNames[peripheral] = name
        NSLog("Calling connect to peripheral on " + name)
        centralManager!.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: NSNumber(value: true as Bool)])
        discoveredDevices.removeValue(forKey: name)
    }
    /**
     * To disconnect from a peripheral we simply cancel the connection and remove
     * it from our connected list
     */
    func disconnectFromPeripheral(_ peripheral: CBPeripheral) -> Bool {
        centralManager?.cancelPeripheralConnection(peripheral)
        connectNames.removeValue(forKey: peripheral)
        return true
    }
    /**
     * This allows us to disconnect from a peripheral by its name. 
     * It returns false if a device by that name is not connected
     */
    func disconnectFromPeripheralbyName(_ name: String) -> Bool {
        for (peripheral, pName) in connectNames {
            if pName == name {
                disconnectFromPeripheral(peripheral)
                return true
            }
        }
        NSLog("Failed to disconnect because peripheral of name: " + name + " count not be found. Known names are: " + connectNames.values.joined(separator: ", "))
        return false
    }
    /**
     * This allows us to rename peripherals to a new name (with a number appended
     * on if that name is already taken)
     */
    func renamePeripheral(_ peripheral: CBPeripheral, newName: String) -> String{
        var localName = String(newName)
        if Array(nameCount.keys.lazy).contains(newName as String) {
            nameCount[newName as String]! += UInt(1)
            localName = localName! + String(nameCount[newName as String]!)
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
                discoveredDevices.removeValue(forKey: validOldName)
                discoveredDevices[localName!] = peripheral
            }
        }
        serviceBLE.renamePeripheral(peripheral, newName: localName)
        return localName!
    }
    /**
     * This allows us to rename peripherals to a new name (with a number appended
     * on if that name is already taken) based on their current name
     */
    func renamePeripheralbyName(_ oldName: String, newName: String) -> String?{
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
    
    func removeConnected(_ name: String) {
        var peripheral: CBPeripheral?
        for (periph, pName) in connectNames {
            if pName == name {
                peripheral = periph
            }
        }
        if let validPeripheral = peripheral{
            connectNames.removeValue(forKey: validPeripheral)
        }
    }
}
