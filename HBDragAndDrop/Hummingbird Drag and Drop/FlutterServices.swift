//
//  FlutterServices.swift
//  BirdBlox
//
//  Created by birdbrain on 2/20/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import CoreBluetooth

open class FlutterServices: NSObject{
    
    static let ServiceUUID = CBUUID(string: "BC2F4CC6-AAEF-4351-9034-D66268E328F0")
    static let TxUUID = CBUUID(string: "06D1E5E7-79AD-4A71-8FAA-373789F7D93C")//sending
    static let RxUUID = CBUUID(string: "818AE306-9C5B-448D-B51A-7ADD6A5D314D")//receiving
    
    //cannot make assumptions about the starting values of the flutter (Might not
    //be zeroed. So we make the starting state something that is impossible
    fileprivate var trileds: [[UInt8]] = [[255,255,255],[255,255,255],[255,255,255]]
    fileprivate var servos: [UInt8] = [255,255,255]
    fileprivate var lastKnowSensorPoll: [UInt8] = [0,0,0]
    fileprivate var name: String = ""
    
    
    var timerDelaySend: Timer?
    var allowSend = true
    let sendInterval = 0.2
    let readInterval = 0.2
    let sharedBluetoothDiscovery = BluetoothDiscovery.getBLEDiscovery()
    let sendQueue = OperationQueue()
    
    public override init(){
        super.init()
        sendQueue.maxConcurrentOperationCount = 1
    }

    //functions for timer
    func timerElapsedSend(){
        self.allowSend = true
        self.stopTimerSend()
    }
    func stopTimerSend(){
        if self.timerDelaySend == nil{
            return
        }
        timerDelaySend?.invalidate()
        self.timerDelaySend = nil
    }
    func startTimerSend(){
        self.allowSend = false
        if (timerDelaySend == nil){
            timerDelaySend = Timer.scheduledTimer(timeInterval: sendInterval, target: self, selector: #selector(FlutterServices.timerElapsedSend), userInfo: nil, repeats: false)
        }
    }
    
    open func disconnectFromDevice(){
        sharedBluetoothDiscovery.disconnectFromPeripheralbyName(self.name)
    }
    
    open func attachToDevice(_ name: String) {
        self.name = name;
        servos = [0,0,0]
        trileds = [[0,0,0],[0,0,0],[0,0,0]]
        lastKnowSensorPoll = [0,0,0]
    }
    
    //Intensity is on a scale of 0-100
    //Angle is on a scale of 0-180
    open func sendByteArray(_ toSend: Data){
        let serviceBLE = sharedBluetoothDiscovery.serviceBLE
        if (sendQueue.operationCount > 15) {
            sendQueue.cancelAllOperations()
        }
        sendQueue.addOperation{
            if(!self.allowSend){
                Thread.sleep(forTimeInterval: self.sendInterval)
            }
            serviceBLE.setTX(self.name, message: toSend)
            self.startTimerSend()
        }
    }
    
    open func recieveByteArray()-> Data{
        let serviceBLE = sharedBluetoothDiscovery.serviceBLE
        let value = serviceBLE.getValues(self.name)
        dbg_print(NSString(format: "got data: %@", value as CVarArg))
        if (value.count >= 4){
            //Note, if receving sensor inputs the 0th element of this array will 
            //be r
            return value
        }
        else{
            return Data()
        }
    }
    
    open func setTriLEDRed(_ port: UInt8, value: UInt8){
        //if(trileds[Int(port) - 1][0] == value){
        //    return;
        //}
        let checked_value = bound(value, min: 0, max: 100)
        let command: Data = getFlutterSet(port, output: "r", value: checked_value)
        trileds[Int(port) - 1][0] = checked_value
        self.sendByteArray(command)
    }
    
    open func setTriLEDGreen(_ port: UInt8, value: UInt8){
        //if(trileds[Int(port) - 1][1] == value){
        //    return;
        //}
        let checked_value = bound(value, min: 0, max: 100)
        let command: Data = getFlutterSet(port, output: "g", value: checked_value)
        trileds[Int(port) - 1][1] = checked_value
        self.sendByteArray(command)
    }
    
    open func setTriLEDBlue(_ port: UInt8, value: UInt8){
        //if(trileds[Int(port) - 1][2] == value){
        //    return;
        //}
        let checked_value = bound(value, min: 0, max: 100)
        let command: Data = getFlutterSet(port, output: "b", value: checked_value)
        trileds[Int(port) - 1][2] = checked_value
        self.sendByteArray(command)
    }
    
    open func setServo(_ port: UInt8, value: UInt8) {
        //if(servos[Int(port) - 1] == value){
        //    return;
        //}
        let checked_value = bound(value, min: 0, max: 180)
        let command: Data = getFlutterSet(port, output: "s", value: checked_value)
        servos[Int(port) - 1] = checked_value
        self.sendByteArray(command)
    }
    
    open func getAllSensorData() -> [UInt8]{
        self.sendByteArray(getFlutterRead() as Data)
        Thread.sleep(forTimeInterval: readInterval)
        var values: [UInt8] = lastKnowSensorPoll
        let result = self.recieveByteArray()
        if (result.count > 0){
            (result as NSData).getBytes(&values, range: NSMakeRange(0, 4))
            lastKnowSensorPoll = Array(values[1..<4])
        }
        return Array(values[1..<4])
    }
}
