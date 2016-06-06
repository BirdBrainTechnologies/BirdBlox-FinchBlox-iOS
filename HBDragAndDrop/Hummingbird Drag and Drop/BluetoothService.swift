//
//  BluetoothService.swift
//  HummingbirdLibrary
//
//  Created by birdbrain on 5/27/15.
//  Copyright (c) 2015 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import CoreBluetooth

let BLEServiceUUID      = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
let BLEServiceUUIDTX    = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")//sending
let BLEServiceUUIDRX    = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")//receiving
let BLEServiceChangedStatusNotification = "kBLEServiceChangedStatusNotification"

class BluetoothService: NSObject, CBPeripheralDelegate{
    
    typealias BLEDevice = (peripheral: CBPeripheral, tx: CBCharacteristic?, rx: CBCharacteristic?, data: NSData, name: String)
    var devices: [BLEDevice] = [BLEDevice]()
    
    deinit{
        self.resetAll()
    }
    
    private func getIndex(name: String) -> Int? {
        let i = devices.indexOf { (device: BLEDevice) -> Bool in
            return device.name == name
        }
        return i
    }
    private func getIndex(peripheral: CBPeripheral) -> Int? {
        let i = devices.indexOf { (device: BLEDevice) -> Bool in
            return device.peripheral == peripheral
        }
        return i
    }
    
    func addPeripheral(peripheral: CBPeripheral, name: String) {
        peripheral.delegate = self
        let device: BLEDevice = (peripheral, nil, nil, NSData(bytes: [0,0,0,0,0] as [UInt8],length: 5), name)
        devices.append(device)
        startDiscoveringServices(name)
    }
    func removePeripheralbyName(name: String) {
        if let i = getIndex(name) {
            devices[i].peripheral.delegate = nil
            devices.removeAtIndex(i)
        }
    }
    
    func removePeripheral(peripheral: CBPeripheral) {
        if let i = getIndex(peripheral) {
            devices[i].peripheral.delegate = nil
            devices.removeAtIndex(i)
        }
    }
    
    func startDiscoveringServices(name: String){
        if let i = getIndex(name) {
            devices[i].peripheral.discoverServices([BLEServiceUUID])
        }
    }
    
    func reset(name: String){
        if let index = getIndex(name) {
            devices.removeAtIndex(index)
        }
        self.sendBTServiceNotification(false)
    }
    
    func resetAll(){
        devices.removeAll()
        self.sendBTServiceNotification(false)
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        let neededUUIDs: [CBUUID] = [BLEServiceUUIDRX,BLEServiceUUIDTX]
        
        if (getIndex(peripheral) == nil){
            dbg_print("not right peripheral")
            return
        }
        if(error != nil){
            dbg_print("error in discover service")
            return
        }
        if let services = peripheral.services{
            for service in services {
                if(service.UUID == BLEServiceUUID){
                    peripheral.discoverCharacteristics(neededUUIDs, forService: service )
                }
            }
        }
    }
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        if(error != nil){
            return
        }
        if let index = getIndex(peripheral){
        var wasTXSet = false
        var wasRXSet = false
            if let characteristics = service.characteristics{
                for characteristic in characteristics {
                    let CBchar = characteristic
                    dbg_print("Found characteristic of uuid" + CBchar.UUID.UUIDString)
                    if(characteristic.UUID == BLEServiceUUIDTX){
                        devices[index].tx = characteristic
                        peripheral.setNotifyValue(true, forCharacteristic: characteristic )
                        wasTXSet = true
                    }
                    else if(characteristic.UUID == BLEServiceUUIDRX){
                        devices[index].rx = characteristic
                        peripheral.setNotifyValue(true, forCharacteristic: characteristic )
                        wasRXSet = true
                    }
                    if(wasTXSet && wasRXSet){
                        dbg_print("tx and rx characteristics were set")
                        self.sendBTServiceNotification(true)
                    }
                }
            }
        }
        else {
            return
        }
    }
    var lastMessageSent:NSData = NSData()
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if(characteristic.UUID != BLEServiceUUIDRX){
            return
        }
        if(characteristic.value!.length % 5 != 0){
            return
        }
        let dataString = NSString(format: "rx value: %@", characteristic.value!)
        dbg_print(dataString)
        if let index = getIndex(peripheral) {
            var temp: [UInt8] = [0,0,0,0]
            characteristic.value!.getBytes(&temp,length: 4)
            var oldData: [UInt8] = [0,0,0,0]
            devices[index].data.getBytes(&oldData, length: 4)
            //if (temp[0] == 0x47 && temp[1] == 0x33 && (temp[2] != 0x47 || temp[3] != 0x33)){//sensor data
                oldData[0] = temp[0]
                oldData[1] = temp[1]
                oldData[2] = temp[2]
                oldData[3] = temp[3]
            //}
            objc_sync_enter(devices[index].peripheral)
            devices[index].data = NSData(bytes: oldData, length: 4)
            objc_sync_exit(devices[index].peripheral)
            dbg_print(NSString(format: "stored data: %@", devices[index].data))
        }
    }
    
    
    func setTX(name: String, message : NSData){
        //dbg_print("setTX called")
        if let index = getIndex(name) {
            if (devices[index].tx == nil){
                dbg_print("tx is not avaliable")
                return
            }
            if(message.isEqualToData (lastMessageSent) && !(message.isEqualToData(getPollSensorsCommand()))){
                dbg_print("ignoring repeat message")
                return
            }
            dbg_print(NSString(format: "sending message %@", message))
            devices[index].peripheral.writeValue(message, forCharacteristic: devices[index].tx!, type: CBCharacteristicWriteType.WithResponse)
            lastMessageSent = message
            dbg_print("sent message")
        }
    }
    
    func getValues(name: String) -> NSData{
        var ret = NSData()
        if let index = getIndex(name) {
            objc_sync_enter(devices[index].peripheral)
            ret = NSData(data: devices[index].data)
            objc_sync_exit(devices[index].peripheral)
        }
        return ret
    }
    
    func sendBTServiceNotification(isConnected: Bool){
        let connectionDetails = ["isConnected" : isConnected]
        NSNotificationCenter.defaultCenter().postNotificationName(BLEServiceChangedStatusNotification, object: self, userInfo: connectionDetails)
    }
    
    
}