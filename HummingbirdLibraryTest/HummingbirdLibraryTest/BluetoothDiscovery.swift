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

class BluetoothDiscovery: NSObject, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager?
    private var peripheralBLE: CBPeripheral?
    private var discoveredDevices = [String: CBPeripheral]()
    private var hasConnectedOnce = false
    private var lastConnectedID: NSUUID = NSUUID(UUIDString: "00000000-0000-0000-0000-000000000000")!
    private var counter: Int = 1;
    
    override init(){
        super.init();
        
        let centralQueue = dispatch_queue_create("com.BirdBrainTech", DISPATCH_QUEUE_SERIAL)
        centralManager = CBCentralManager(delegate: self, queue: centralQueue)
    }
    
    func startScan(){
        counter = 1;
        if let central = centralManager{
            discoveredDevices = [String: CBPeripheral]()
            dbg_print("looking for devices with a service of UUID: " + BLEServiceUUID.UUIDString)
            central.scanForPeripheralsWithServices([BLEServiceUUID], options: nil)
            //central.scanForPeripheralsWithServices(nil, options: nil)
        }
    }
    func restartScan(){
        if let central = centralManager{
            central.stopScan()
            startScan()
        }
    }
    
    var serviceBLE: BluetoothService?{
        didSet{
            if let service = self.serviceBLE{
                service.startDiscoveringServices()
            }
        }
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [NSObject : AnyObject], RSSI: NSNumber) {
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
            let localname = String(counter) + String(". ") + (nameString as String)
            counter++
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
            //self.peripheralBLE = peripheral
            //self.serviceBLE = nil
            //central.cancelPeripheralConnection(peripheral)
            //central.connectPeripheral(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: NSNumber(bool:true)])
        }
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        if (self.peripheralBLE == peripheral){
            dbg_print("connected to device: " + self.peripheralBLE!.name!)
            lastConnectedID = peripheral.identifier
            hasConnectedOnce = true
            self.serviceBLE = BluetoothService(initWithPeripheral: self.peripheralBLE!)
        }
        central.stopScan()
    }
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        
        if(peripheral == self.peripheralBLE){
            dbg_print("Disconnected from device, will start scanning")
            self.clearDevices()
        }
        self.startScan()
    }
    
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
    
    func connectToPeripheral(peripheral: CBPeripheral){
        self.peripheralBLE = peripheral
        self.serviceBLE = nil
        centralManager!.cancelPeripheralConnection(peripheral)
        centralManager!.connectPeripheral(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: NSNumber(bool:true)])
    }
    
    func disconnectFromPeripheral(){
        centralManager?.cancelPeripheralConnection(peripheralBLE!)
    }
    
    func getDiscovered() -> [String:CBPeripheral]{
        return discoveredDevices
    }
}