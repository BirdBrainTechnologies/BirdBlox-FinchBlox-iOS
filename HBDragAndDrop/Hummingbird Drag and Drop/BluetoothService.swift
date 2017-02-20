//
//  BluetoothService.swift
//  HummingbirdLibrary
//
//  Created by birdbrain on 5/27/15.
//  Copyright (c) 2015 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import CoreBluetooth

public let BluetoothStatusChangedNotification = "BluetoothStatusChanged"

class BluetoothService: NSObject, CBPeripheralDelegate{
    
    internal var commandsSend = 0
    var resetTimer: Timer = Timer()
    
    //This typedef contains all the relevant info about a bluetooth device (hummingbird)
    typealias BLEDevice = (peripheral: CBPeripheral, tx: CBCharacteristic?, rx: CBCharacteristic?, data: Data, name: String, type: String)
    
    //This is a list of all of the connected BLE devices. There is some redundancy
    //here between this list and the connected devices list in the discovery
    //class
    var devices: [BLEDevice] = [BLEDevice]()
    
    deinit{
        self.resetAll()
    }
    
    fileprivate func getIndex(_ name: String) -> Int? {
        let i = devices.index { (device: BLEDevice) -> Bool in
            return device.name == name
        }
        return i
    }
    fileprivate func getIndex(_ peripheral: CBPeripheral) -> Int? {
        let i = devices.index { (device: BLEDevice) -> Bool in
            return device.peripheral == peripheral
        }
        return i
    }
    
    /**
     * This adds a peripheral to our BLE devices list and begins the process
     * of discovering the services the device has
     */
    func addPeripheral(_ peripheral: CBPeripheral, name: String) {
        peripheral.delegate = self
        let device: BLEDevice = (peripheral, nil, nil, Data(bytes: UnsafePointer<UInt8>([0,0,0,0,0] as [UInt8]),count: 5), name, type: "")
        devices.append(device)
        startDiscoveringServices(name)
        
    }
    func removePeripheralbyName(_ name: String) {
        if let i = getIndex(name) {
            let type = devices[i].type
            devices[i].peripheral.delegate = nil
            devices.remove(at: i)
            self.sendBTServiceNotification(false, name: name, type: type)
        }
    }
    
    func removePeripheral(_ peripheral: CBPeripheral) {
        if let i = getIndex(peripheral) {
            let type = devices[i].type
            devices[i].peripheral.delegate = nil
            let device = devices.remove(at: i)
            self.sendBTServiceNotification(false, name: device.name, type: type)
        }
    }
    
    func renamePeripheral(_ peripheral: CBPeripheral, newName: String) {
        if let i = getIndex(peripheral) {
            devices[i].name = newName
        }
    }
    
    func startDiscoveringServices(_ name: String){
        if let i = getIndex(name) {
            devices[i].peripheral.discoverServices(serviceUUIDs)
        }
    }
    /**
     * This removes a device from our device list and tell the discovery class
     * that the device has been disconnected
     */
    func reset(_ name: String){
        if let index = getIndex(name) {
            let device = devices.remove(at: index)
            self.sendBTServiceNotification(false, name: device.name, type: device.type)
        }
        
    }
    
    func resetAll(){
        devices.removeAll()
        self.sendBTServiceNotification(false, name: "~!!!!!!!!!!~", type: "")
    }
    /**
     * This is called when a service is discovered for a peripheral
     * We specifically want the GATT service and start discovering characteristics
     * for that GATT service
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
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
                if(service.uuid == HummingbirdServices.ServiceUUID){
                    let neededUUIDs: [CBUUID] = [HummingbirdServices.RxUUID,HummingbirdServices.TxUUID]
                    if let i = getIndex(peripheral) {
                        devices[i].type = "hummingbird"
                    }
                    peripheral.discoverCharacteristics(neededUUIDs, for: service )
                }
                else if (service.uuid == FlutterServices.ServiceUUID) {
                    let neededUUIDs: [CBUUID] = [FlutterServices.RxUUID,FlutterServices.TxUUID]
                    if let i = getIndex(peripheral) {
                        devices[i].type = "flutter"
                    }
                    peripheral.discoverCharacteristics(neededUUIDs, for: service)
                }
            }
        }
    }
    /**
     * Once we find a characteristic, we check if it is the RX or TX line that was
     * found. Once we have found both, we send a notification saying the device
     * is now conencted
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if(error != nil){
            return
        }
        if let index = getIndex(peripheral){
            var wasTXSet = false
            var wasRXSet = false
            if let characteristics = service.characteristics{
                for characteristic in characteristics {
                    
                    var tx_uuid: CBUUID, rx_uuid: CBUUID
                    if service.uuid == HummingbirdServices.ServiceUUID {
                        tx_uuid = HummingbirdServices.TxUUID
                        rx_uuid = HummingbirdServices.RxUUID
                    } else if service.uuid == FlutterServices.ServiceUUID {
                        tx_uuid = FlutterServices.TxUUID
                        rx_uuid = FlutterServices.RxUUID
                    } else {
                        return
                    }
                    
                    if(characteristic.uuid == tx_uuid){
                        devices[index].tx = characteristic
                        peripheral.setNotifyValue(true, for: characteristic )
                        wasTXSet = true
                    }
                    else if(characteristic.uuid == rx_uuid){
                        devices[index].rx = characteristic
                        peripheral.setNotifyValue(true, for: characteristic )
                        wasRXSet = true
                    }
                    
                    if(wasTXSet && wasRXSet){
                        dbg_print("tx and rx characteristics were set")
                        dbg_print("Sending Notification with name: " + devices[index].name)
                        self.sendBTServiceNotification(true, name: devices[index].name, type: devices[index].type)
                        return
                    }
                }
            }
        }
        else {
            return
        }
    }
    var lastMessageSent:Data = Data()
    var lastNameSent: String = ""
    
    /*
     * When the RX characteristic gets updated, it should contain the latest
     * sensor info from the hummingbird
     * We make sure the data is well formatted and then store that data
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        //let dataString = NSString(format: "rx value: %@", characteristic.value!)
        //dbg_print(dataString)
        if let index = getIndex(peripheral) {
            if(characteristic.uuid != devices[index].rx){
                return
            }
            if(characteristic.uuid == HummingbirdServices.RxUUID && characteristic.value!.count % 5 != 0){
                return
            }
            if(characteristic.uuid == FlutterServices.RxUUID && characteristic.value!.count % 4 != 0){
                return
            }
            var temp: [UInt8] = [0,0,0,0]
            (characteristic.value! as NSData).getBytes(&temp,length: 4)
            var oldData: [UInt8] = [0,0,0,0]
            (devices[index].data as NSData).getBytes(&oldData, length: 4)
                oldData[0] = temp[0]
                oldData[1] = temp[1]
                oldData[2] = temp[2]
                oldData[3] = temp[3]
            objc_sync_enter(devices[index].peripheral)
            devices[index].data = Data(bytes: UnsafePointer<UInt8>(oldData), count: 4)
            objc_sync_exit(devices[index].peripheral)
            //dbg_print(NSString(format: "stored data: %@", devices[index].data))
        }
    }
    
    
    func setTX(_ name: String, message : Data){
        //dbg_print(NSString(format: "setTX called on %@", name))
        if let index = getIndex(name) {
            if (devices[index].tx == nil){
                dbg_print("tx is not avaliable")
                return
            }
            if((message == lastMessageSent) && name == lastNameSent && !(message == getPollSensorsCommand() as Data)){
                //dbg_print("ignoring repeat message")
                return
            }
            //dbg_print(NSString(format: "sending message %@", message))
            devices[index].peripheral.writeValue(message, for: devices[index].tx!, type: CBCharacteristicWriteType.withResponse)
            lastMessageSent = message
            lastNameSent = name
            commandsSend += 1
            //dbg_print("sent message")
        }
    }
    
    func getValues(_ name: String) -> Data{
        var ret = Data()
        if let index = getIndex(name) {
            objc_sync_enter(devices[index].peripheral)
            ret = NSData(data: devices[index].data) as Data
            objc_sync_exit(devices[index].peripheral)
        }
        return ret
    }
    
    func getDeviceNames() -> [String] {
        let names = devices.map { (peripheral: CBPeripheral, tx: CBCharacteristic?, rx: CBCharacteristic?, data: Data, name: String, type: String) -> String in
            return name
        }
        return names
    }
    
    func sendBTServiceNotification(_ isConnected: Bool, name: String, type: String){
        let connectionDetails = ["isConnected" : isConnected, "name" : name, "type" : type] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name(rawValue: BluetoothStatusChangedNotification), object: self, userInfo: connectionDetails as [AnyHashable: Any])
    }
    
    
}
