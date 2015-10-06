//
//  BluetoothDiscovery.swift
//  HummingbirdLibrary
//
//  Created by birdbrain on 5/26/15.
//  Copyright (c) 2015 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import CoreBluetooth

let sharedBluetoothDiscovery = BluetoothDiscovery()

/**
:Class: BluetoothDiscovery

The class responsible for discovering new bluetooth devices and initializing a connection with them
*/
class BluetoothDiscovery: NSObject, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager?
    private var peripheralBLE: CBPeripheral?
    private var discoveredDevices = [String: CBPeripheral]()
    private var hasConnectedOnce = false
    private var lastConnectedID: NSUUID = NSUUID(UUIDString: "00000000-0000-0000-0000-000000000000")!
    
    override init(){
        super.init();
        
        let centralQueue = dispatch_queue_create("com.BirdBrainTech", DISPATCH_QUEUE_SERIAL)
        centralManager = CBCentralManager(delegate: self, queue: centralQueue)
    }
    /**
        Begins looking for new bluetooth LE devices of a specific UUID
    */
    func startScan(){
        if let central = centralManager{
            discoveredDevices = [String: CBPeripheral]()
            dbg_print("looking for devices with a service of UUID: " + BLEServiceUUID.UUIDString)
            central.scanForPeripheralsWithServices([BLEServiceUUID], options: nil)
            //central.scanForPeripheralsWithServices(nil, options: nil)
        }
    }
    /**
        Restarts the scan for bluetooth devices
    */
    func restartScan(){
        if let central = centralManager{
            central.stopScan()
            startScan()
        }
    }
    /**
        Once connected, we will start discovering services
    */
    var serviceBLE: BluetoothService?{
        didSet{
            if let service = self.serviceBLE{
                service.startDiscoveringServices()
            }
        }
    }
    /**
        :Additional Info: After a device has been discovered, we will add it to our list of discovered devices unless we have connected to it before. In that case we simply reconnect to it.
    */
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        if((peripheral.name == nil) || (peripheral.name == "")){
            return
        }
        if ((self.peripheralBLE == nil) || (self.peripheralBLE?.state == CBPeripheralState.Disconnected)){
            
            var nameString: NSString = NSString()
            if let ns: AnyObject = advertisementData[CBAdvertisementDataLocalNameKey] as? NSString{
                nameString = ns as! NSString
            }
            else{
                nameString = peripheral.name!
            }
            let localname = nameString as String
                
            dbg_print("Found a device: " + localname)
            
            if(hasConnectedOnce){
                if(peripheral.identifier == lastConnectedID){
                    connectToPeripheral(peripheral)
                    return
                }
            }
            
            var alreadyAdded: Bool = false
            for (_, alreadyFound) in discoveredDevices{
                if (alreadyFound.identifier == peripheral.identifier){
                    alreadyAdded = true
                }
            }
            if(!alreadyAdded){
                discoveredDevices[localname] = peripheral
            }
        }
    }
    /**
        :Additional Info: After a device has been connected to, we make a new service from it
    */
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        if (self.peripheralBLE == peripheral){
            dbg_print("connected to device: " + self.peripheralBLE!.name!)
            lastConnectedID = peripheral.identifier
            hasConnectedOnce = true
            self.serviceBLE = BluetoothService(initWithPeripheral: self.peripheralBLE!)
        }
        central.stopScan()
    }
    /**
        :Additional Info: After a device has been disconnected, we start scanning again
    */
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        
        if(peripheral == self.peripheralBLE){
            dbg_print("Disconnected from device, will start scanning")
            self.clearDevices()
        }
        self.startScan()
    }
    /**
        clears the current bluetooth device we're connected to
    */
    func clearDevices(){
        self.serviceBLE = nil
        self.peripheralBLE = nil
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
            //clearDevices
            self.clearDevices()
            break
            
        case CBCentralManagerState.Unsupported:
            break
        }

    }
    /**
        Initiates a new connection with a BLE device
    */
    func connectToPeripheral(peripheral: CBPeripheral){
        self.peripheralBLE = peripheral
        self.serviceBLE = nil
        centralManager!.cancelPeripheralConnection(peripheral)
        centralManager!.connectPeripheral(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: NSNumber(bool:true)])
    }
    /**
        Disconnects from the BLE device we're currently connected to
    */
    func disconnectFromPeripheral(){
        centralManager?.cancelPeripheralConnection(peripheralBLE!)
    }
    /**
        Get the list of devices we have discovered
    
        :returns: [String:CBPeripheral] a maping of a device name to the device of the devices we have found so far
    */
    func getDiscovered() -> [String:CBPeripheral]{
        return discoveredDevices
    }
}