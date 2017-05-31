//
//  HummingbirdPeripheral.swift
//  BirdBlox
//
//  Created by birdbrain on 3/23/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import CoreBluetooth

class HummingbirdPeripheral: NSObject, CBPeripheralDelegate {
    fileprivate var peripheral: CBPeripheral
    fileprivate let BLE_Manager: BLECentralManager
    static let DEVICE_UUID         = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")//BLE adapter
    static let SERVICE_UUID        = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")//UART Service
    static let TX_UUID             = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")//sending
    static let RX_UUID             = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")//receiving
    static let RX_CONFIG_UUID      = CBUUID(string: "00002902-0000-1000-8000-00805f9b34fb")
    var rx_line, tx_line: CBCharacteristic?
    
    var last_message_sent: Data = Data()
    
    fileprivate var vibrations: [UInt8] = [0,0]
    fileprivate var vibrations_time: [Double] = [0,0]
    fileprivate var motors: [Int] = [0,0]
    fileprivate var motors_time: [Double] = [0,0]
    fileprivate var servos: [UInt8] = [0,0,0,0]
    fileprivate var servos_time: [Double] = [0,0,0,0]
    fileprivate var leds: [UInt8] = [0,0,0,0]
    fileprivate var leds_time: [Double] = [0,0,0,0]
    fileprivate var trileds: [[UInt8]] = [[0,0,0],[0,0,0]]
    fileprivate var trileds_time: [Double] = [0,0]
    var last_message_recieved: [UInt8] = [0,0,0,0]
    let cache_timeout: Double = 15.0 //in seconds
    var was_initialized = false
    fileprivate var setTimer: Timer = Timer()

    
    init(peripheral: CBPeripheral){
        self.peripheral = peripheral
        self.BLE_Manager = BLECentralManager.manager
        super.init()
        self.peripheral.delegate = self
        
        self.peripheral.discoverServices([HummingbirdPeripheral.SERVICE_UUID])
    }
    
    /**
     * This is called when a service is discovered for a peripheral
     * We specifically want the GATT service and start discovering characteristics
     * for that GATT service
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if (peripheral != self.peripheral || error != nil) {
            //not the right device
            return
        }
        if let services = peripheral.services{
            for service in services {
                if(service.uuid == HummingbirdPeripheral.SERVICE_UUID){
                    peripheral.discoverCharacteristics([HummingbirdPeripheral.RX_UUID, HummingbirdPeripheral.TX_UUID], for: service)
                    return
                }
            }
        }
    }
    /**
     * Once we find a characteristic, we check if it is the RX or TX line that was
     * found. Once we have found both, we send a notification saying the device
     * is now conencted
     */
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if (peripheral != self.peripheral || error != nil) {
            //not the right device
            return
        }
        var wasTXSet = false
        var wasRXSet = false
        if let characteristics = service.characteristics{
            for characteristic in characteristics {
                if(characteristic.uuid == HummingbirdPeripheral.TX_UUID){
                    tx_line = characteristic
                    peripheral.setNotifyValue(true, for: characteristic )
                    wasTXSet = true
                }
                else if(characteristic.uuid == HummingbirdPeripheral.RX_UUID){
                    rx_line = characteristic
                    peripheral.setNotifyValue(true, for: characteristic )
                    wasRXSet = true
                }
                if(wasTXSet && wasRXSet){
                    initialize()
                    return
                }
            }
        }
    }
    
    fileprivate func initialize() {
        sendData(data: getTurnOffCommand())
        Thread.sleep(forTimeInterval: 0.1)
        sendData(data: getPollStopCommand())
        Thread.sleep(forTimeInterval: 0.1)
        sendData(data: getPollStartCommand())
        DispatchQueue.main.async{
            self.setTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self,
                                                 selector: #selector(HummingbirdPeripheral.setAll),
												 userInfo: nil, repeats: true)
            self.setTimer.fire()
        }
        was_initialized = true
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if(characteristic.uuid != HummingbirdPeripheral.RX_UUID){
            return
        }
        if(characteristic.value!.count % 5 != 0){
            return
        }
        objc_sync_enter(self.peripheral)
        (characteristic.value! as NSData).getBytes(&self.last_message_recieved, length: 4)
        objc_sync_exit(self.peripheral)
    }
    
    /**
     * Called when we update a characteristic
     */
    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
		if let error = error {
			NSLog("Unable to write to hummingbird due to error \(error)")
		}
        
    }
    
    func disconnect() {
        BLE_Manager.disconnect(peripheral: peripheral)
    }
    
    func isConnected () -> Bool {
        return peripheral.state == CBPeripheralState.connected
    }
    
    func getData() -> [UInt8]? {
        return self.last_message_recieved
    }
    
    func sendData(data: Data) {
        peripheral.writeValue(data, for: tx_line!, type: CBCharacteristicWriteType.withResponse)
    }
    
    
    //What follows are all the functions for setting outputs and getting inputs
    //Most of this code has been commented out as we switch to the new method
    //of setting outputs 
    //TODO: add a check for legacy firmware and use set all for only
    //firmwares newer than 2.2.a 
    func setLED(port: Int, intensity: UInt8) -> Bool {
        let i = port - 1
        /*
        let current_time = NSDate().timeIntervalSince1970
        if(leds[i] == intensity && (current_time - leds_time[i]) < cache_timeout){
            return false
        }
        let command: Data = getLEDCommand(UInt8(port), intensity: intensity)
        self.sendData(data: command)
        leds_time[i] = current_time
        */
        leds[i] = intensity
        return true
    }
    
    func setTriLed(port: Int, r: UInt8, g: UInt8, b:UInt8) -> Bool {
        let i = port - 1
        /*
        let current_time = NSDate().timeIntervalSince1970
        if(trileds[i] == [r,g,b] && (current_time - trileds_time[i]) < cache_timeout){
            return false
        }
        let command = getTriLEDCommand(UInt8(port), red_val: r, green_val: g, blue_val: b)
        self.sendData(data: command)
        trileds_time[i] = current_time
         */
        trileds[i] = [r,g,b]

        return true
    }
    
    func setVibration(port: Int, intensity: UInt8) -> Bool {
        let i = port - 1
        /*
        let current_time = NSDate().timeIntervalSince1970
        if(vibrations[i] == intensity && (current_time - vibrations_time[i]) < cache_timeout){
            return false
        }
        let command: Data = getVibrationCommand(UInt8(port), intensity: intensity)
        
        self.sendData(data: command)
        vibrations_time[i] = current_time
        */
        vibrations[i] = intensity
        return true
    }
    
    func setMotor(port: Int, speed: Int) -> Bool {
        let i = port - 1
        /*
        let current_time = NSDate().timeIntervalSince1970
        if(motors[i] == speed && (current_time - motors_time[i]) < cache_timeout){
            return false
        }
        let command: Data = getMotorCommand(UInt8(port), speed: speed)
        self.sendData(data: command)
        motors_time[i] = current_time
        */
        motors[i] = speed
        return true
    }
    
    func setServo(port: Int, angle: UInt8) -> Bool {
        let i = port - 1
        /*
        let current_time = NSDate().timeIntervalSince1970
        if(servos[i] == angle && (current_time - servos_time[i]) < cache_timeout){
            return false
        }
        let command: Data = getServoCommand(UInt8(port), angle: angle)
        self.sendData(data: command)
        servos_time[i] = current_time
        */
        servos[i] = angle
        return true
    }
    
    func setAll() {
        let command = getSetAllCommand(tri: trileds, leds: leds, servos: servos, motors: motors, vibs: vibrations)
        print("Setting All: " + command.description)
        self.sendData(data: command)
    }
}
