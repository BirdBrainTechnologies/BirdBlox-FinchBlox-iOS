//
//  HummingbirdServices.swift
//  HummingbirdLibrary
//
//  Created by birdbrain on 5/28/15.
//  Copyright (c) 2015 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import CoreBluetooth

public let BluetoothStatusChangedNotification = "BluetoothStatusChangedForHummingbird"

open class HummingbirdServices: NSObject{
    fileprivate var vibrations: [UInt8] = [0,0]
    fileprivate var motors: [Int] = [0,0]
    fileprivate var servos: [UInt8] = [0,0,0,0]
    fileprivate var leds: [UInt8] = [0,0,0,0]
    fileprivate var trileds: [[UInt8]] = [[0,0,0],[0,0,0]]
    fileprivate var lastKnowSensorPoll: [UInt8] = [0,0,0,0]
    fileprivate var name: String = ""
    
    
    var timerDelaySend: Timer?
    var allowSend = true
    let sendInterval = 0.06
    let readInterval = 0.2
    let sharedBluetoothDiscovery = BluetoothDiscovery.getBLEDiscovery()
    let sendQueue = OperationQueue()
    
    
    public override init(){
        super.init()
        sendQueue.maxConcurrentOperationCount = 1
        NotificationCenter.default.addObserver(self, selector: #selector(HummingbirdServices.connectionChanged(_:)), name: NSNotification.Name(rawValue: BLEServiceChangedStatusNotification), object: nil)
    }
    
    deinit{
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: BLEServiceChangedStatusNotification), object: nil)
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
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: BLEServiceChangedStatusNotification), object: nil)

    }
    
    open func attachToDevice(_ name: String) {
        self.name = name;
        vibrations = [0,0]
        motors = [0,0]
        servos = [0,0,0,0]
        leds = [0,0,0,0]
        trileds = [[0,0,0],[0,0,0]]
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
        if(leds[realPort] == intensity){
            return;
        }
        let command: Data = getLEDCommand(port, intensity: intensity)
        leds[realPort] = intensity
        self.sendByteArray(command)
    }
    
    open func setTriLED(_ port: UInt8, r: UInt8, g: UInt8, b: UInt8){
        let realPort = Int(port-1)
        if(trileds[realPort] == [r,g,b]){
            return;
        }
        let command: Data = getTriLEDCommand(port, redVal: r, greenVal: g, blueVal: b)
        trileds[realPort] = [r,g,b]
        self.sendByteArray(command)
    }
    
    open func setMotor(_ port: UInt8, speed: Int){
        let realPort = Int(port-1)
        if(motors[realPort] == speed){
            return
        }
        let command: Data = getMotorCommand(port, speed: speed)
        motors[realPort] = speed
        self.sendByteArray(command)
    }
    
    open func setVibration(_ port: UInt8, intensity: UInt8){
        let realPort = Int(port-1)
        if(vibrations[realPort] == intensity){
            return
        }
        let command: Data = getVibrationCommand(port, intensity: intensity)
        vibrations[realPort] = intensity
        self.sendByteArray(command)
    }
    
    open func setServo(_ port: UInt8, angle: UInt8){
        let realPort = Int(port-1)
        if(servos[realPort] == angle){
            return
        }
        let command: Data = getServoCommand(port, angle: angle)
        servos[realPort] = angle
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
    
    func connectionChanged(_ notification: Notification){
        let userinfo = notification.userInfo! as [AnyHashable: Any]
        if let isConnected: Bool = userinfo["isConnected"] as? Bool{
            let connectionDetails = ["isConnected" : isConnected, "name": self.name] as [String : Any]
            NotificationCenter.default.post(name: Notification.Name(rawValue: BluetoothStatusChangedNotification), object: self, userInfo: connectionDetails as [AnyHashable: Any])
        }
    }

}
