//
//  HummingbirdServices.swift
//  HummingbirdLibrary
//
//  Created by birdbrain on 5/28/15.
//  Copyright (c) 2015 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import CoreBluetooth

open class HummingbirdServices: NSObject{
    static let ServiceUUID      = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")//BLE adapter for HB
    static let TxUUID    = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")//sending
    static let RxUUID    = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")//receiving
    
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
    fileprivate var lastKnowSensorPoll: [UInt8] = [0,0,0,0]
    fileprivate var name: String = ""
    
    
    var timerDelaySend: Timer?
    var allowSend = true
    let sendInterval = 0.06
    let readInterval = 0.2
    let cache_timeout: Double = 15.0 //in seconds
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
            timerDelaySend = Timer.scheduledTimer(timeInterval: sendInterval, target: self, selector: #selector(HummingbirdServices.timerElapsedSend), userInfo: nil, repeats: false)
        }
    }
 
    open func disconnectFromDevice(){
        sharedBluetoothDiscovery.disconnectFromPeripheralbyName(self.name)
    }
    
    open func attachToDevice(_ name: String) {
        self.name = name;
        vibrations = [0,0]
        vibrations_time = [0,0]
        motors = [0,0]
        motors_time = [0,0]
        servos = [0,0,0,0]
        servos_time = [0,0,0,0]
        leds = [0,0,0,0]
        leds_time = [0,0,0,0]
        trileds = [[0,0,0],[0,0,0]]
        trileds_time = [0,0]
        lastKnowSensorPoll = [0,0,0,0]
    }
    
    open func renameDevice(_ name: String) -> String? {
        let oldName = self.name
        if let newName = (sharedBluetoothDiscovery.renamePeripheralbyName(oldName, newName: name)) {
            self.name = newName
            return self.name
        }
        return nil
    }
    
    //functions for communicating with device.
    
    //Intensity is on a scale of 0-100
    //Speed is on a scale of -100-100
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
            return value
        }
        else{
            return Data()
        }
    }
    
    open func setLED(_ port: UInt8, intensity: UInt8){
        let realPort = Int(port-1)
        let checked_intensity = bound(intensity, min: 0, max: 100)
        let current_time = NSDate().timeIntervalSince1970
        if(leds[realPort] == checked_intensity && (current_time - leds_time[realPort]) < cache_timeout){
            return;
        }
        let command: Data = getLEDCommand(port, intensity: checked_intensity)
        leds[realPort] = checked_intensity
        leds_time[realPort] = current_time
        self.sendByteArray(command)
    }
    
    open func setTriLED(_ port: UInt8, r: UInt8, g: UInt8, b: UInt8){
        let realPort = Int(port-1)
        let checked_r = bound(r, min: 0, max: 100)
        let checked_g = bound(g, min: 0, max: 100)
        let checked_b = bound(b, min: 0, max: 100)
        let current_time = NSDate().timeIntervalSince1970
        if(trileds[realPort] == [checked_r, checked_g, checked_b] && (current_time - trileds_time[realPort]) < cache_timeout){
            return;
        }
        let command: Data = getTriLEDCommand(port, redVal: checked_r, greenVal: checked_g, blueVal: checked_b)
        trileds[realPort] = [checked_r, checked_g, checked_b]
        trileds_time[realPort] = current_time
        self.sendByteArray(command)
    }
    
    open func setMotor(_ port: UInt8, speed: Int){
        let realPort = Int(port-1)
        let checked_speed = bound(speed, min: -100, max: 100)
        let current_time = NSDate().timeIntervalSince1970
        if(motors[realPort] == checked_speed && (current_time - motors_time[realPort]) < cache_timeout){
            return
        }
        let command: Data = getMotorCommand(port, speed: checked_speed)
        motors[realPort] = checked_speed
        motors_time[realPort] = current_time

        self.sendByteArray(command)
    }
    
    open func setVibration(_ port: UInt8, intensity: UInt8){
        let realPort = Int(port-1)
        let checked_intensity = bound(intensity, min: 0, max: 100)
        let current_time = NSDate().timeIntervalSince1970
        if(vibrations[realPort] == checked_intensity && (current_time - vibrations_time[realPort]) < cache_timeout){
            return
        }
        let command: Data = getVibrationCommand(port, intensity: checked_intensity)
        vibrations[realPort] = checked_intensity
        vibrations_time[realPort] = current_time

        self.sendByteArray(command)
    }
    
    open func setServo(_ port: UInt8, angle: UInt8){
        let realPort = Int(port-1)
        let checked_angle = bound(angle, min: 0, max: 180)
        let current_time = NSDate().timeIntervalSince1970
        if(servos[realPort] == checked_angle && (current_time - servos_time[realPort]) < cache_timeout){
            return
        }
        let command: Data = getServoCommand(port, angle: checked_angle)
        servos[realPort] = checked_angle
        servos_time[realPort] = current_time
        self.sendByteArray(command)
    }
    
    open func resetHummingBird(){
        self.sendByteArray(getResetCommand() as Data)
    }
    
    open func turnOffLightsMotor(){
        self.sendByteArray(getTurnOffCommand() as Data)
    }
    
    open func getAllSensorData() ->[UInt8]{
        self.sendByteArray(getPollSensorsCommand() as Data)
        Thread.sleep(forTimeInterval: readInterval)
        var values: [UInt8] = lastKnowSensorPoll
        let result = self.recieveByteArray()
        if (result.count > 0){
            (result as NSData).getBytes(&values, range: NSMakeRange(0, 4))
            lastKnowSensorPoll = values
        }
        return values
    }
    
    open func getSensorData(_ port: UInt8) -> UInt8{
        let realPort = port-1
        let sensorData: [UInt8] = getAllSensorData()
        return sensorData[Int(realPort)]
    }
    
    open func beginPolling(){
        sendByteArray(getPollStartCommand() as Data)
    }
    open func stopPolling(){
        sendByteArray(getPollStopCommand() as Data)
    }
    open func getAllSensorDataFromPoll() ->[UInt8]{
        var values: [UInt8] = lastKnowSensorPoll
        let result = self.recieveByteArray()
        if (result.count > 0){
            (result as NSData).getBytes(&values, range: NSMakeRange(0, 4))
            lastKnowSensorPoll = values
        }
        return values
    }
    open func getSensorDataFromPoll(_ port: UInt8) -> UInt8{
        let realPort = port-1
        let sensorData: [UInt8] = getAllSensorDataFromPoll()
        return sensorData[Int(realPort)]
    }
    
    open func setName(_ name: String){
        var adjustedName: String = name
        if (name.characters.count > 18){
            adjustedName = (name as NSString).substring(to: 18)
        }
        let command1: Data = StringToCommand("+++")//command mode
        let namePhrase: String = "AT+GAPDEVNAME="
        let command2_1: Data = StringToCommandNoEOL(namePhrase)//name command
        let command2_2: Data = StringToCommand(adjustedName) //set actual name
        let command3: Data = StringToCommand("ATZ")//reset
        
        self.sendByteArray(command1)
        Thread.sleep(forTimeInterval: 0.2)
        self.sendByteArray(command2_1)
        Thread.sleep(forTimeInterval: 0.2)
        self.sendByteArray(command2_2)
        Thread.sleep(forTimeInterval: 0.2)
        self.sendByteArray(command3)
        self.name = name
        dbg_print("finished setting new name")
    }
    
    open func getName() -> String {
        return self.name
    }
    
    open func factoryReset(){
        let command1: Data = StringToCommand("+++")//command mode
        let command2: Data = StringToCommand("AT+FACTORYRESET")
        self.sendByteArray(command1)
        Thread.sleep(forTimeInterval: 0.2)
        self.sendByteArray(command2)
    }

}
