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
    private var nameCount = [String: UInt]()
    private var discoveredDevices = [String: CBPeripheral]()
    private var isScanning = false
    
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
                dbg_print("looking for devices with a service of UUID: " + BLEServiceUUID.UUIDString)
                central.scanForPeripheralsWithServices([BLEServiceUUID], options: nil)
                //central.scanForPeripheralsWithServices(nil, options: nil)
            }
        }
    }
    func stopScan() {
        if isScanning {
            if let central = centralManager{
                central.stopScan()
                isScanning = false
            }
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
            if let ns: AnyObject = advertisementData[CBAdvertisementDataLocalNameKey] as? NSString{
                nameString = ns as! NSString
            }
            else{
                nameString = peripheral.name!
            }
            var localname = String(nameString)
            if Array(nameCount.keys.lazy).contains(nameString as String) {
                nameCount[nameString as String]! += UInt(1)
                localname = localname + String(nameCount[nameString as String]!)
            } else {
                nameCount[nameString as String] = 1
            }
            dbg_print("Found a device: " + localname)
        
            if(Array(connectNames.keys.lazy).contains(peripheral)){
                connectToPeripheral(peripheral, name: localname)
                return
            }
            if(!discoveredDevices.values.contains(peripheral)){
                discoveredDevices[localname] = peripheral
            }
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        let name = connectNames[peripheral]!
        dbg_print("connected to device: " + name)
        self.serviceBLE.addPeripheral(peripheral, name: name)
        stopScan()
    }
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        self.serviceBLE.removePeripheral(peripheral)
        self.startScan()
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
        centralManager!.connectPeripheral(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: NSNumber(bool:true)])
        discoveredDevices.removeValueForKey(name)
    }
    
    func disconnectFromPeripheral(peripheral: CBPeripheral){
        centralManager?.cancelPeripheralConnection(peripheral)
        connectNames.removeValueForKey(peripheral)
    }
    func disconnectFromPeripheralbyName(name: String) {
        for (peripheral, pName) in connectNames {
            if pName == name {
                disconnectFromPeripheral(peripheral)
                return
            }
        }

    }
    
    func getDiscovered() -> [String:CBPeripheral]{
        return discoveredDevices
    }
}