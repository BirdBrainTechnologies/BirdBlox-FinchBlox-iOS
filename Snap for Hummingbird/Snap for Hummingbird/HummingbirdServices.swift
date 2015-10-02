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

public class HummingbirdServices: NSObject{
    var vibrations: [UInt8] = [0,0]
    var motors: [Int] = [0,0]
    var servos: [UInt8] = [0,0,0,0]
    var leds: [UInt8] = [0,0,0,0]
    var trileds: [[UInt8]] = [[0,0,0],[0,0,0]]
    var lastKnowSensorPoll: [UInt8] = [0,0,0,0]
    
    
    var timerDelaySend: NSTimer?
    var allowSend = true
    let sendInterval = 0.01
    let readInterval = 0.2
    
    
    public override init(){
        super.init()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("connectionChanged:"), name: BLEServiceChangedStatusNotification, object: nil)
        sharedBluetoothDiscovery
    }
    
    deinit{
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BLEServiceChangedStatusNotification, object: nil)
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
            timerDelaySend = NSTimer.scheduledTimerWithTimeInterval(sendInterval, target: self, selector: Selector("timerElapsedSend"), userInfo: nil, repeats: false)
        }
    }
 
    
    //functions for connected to a new device
    public func getAvailiableDevices() -> [String: CBPeripheral]{
        return sharedBluetoothDiscovery.getDiscovered()
    }
    public func connectToDevice(peripheral: CBPeripheral){
        sharedBluetoothDiscovery.connectToPeripheral(peripheral)
    }
    public func disconnectFromDevice(){
        sharedBluetoothDiscovery.disconnectFromPeripheral()
    }
    public func restartScan(){
        sharedBluetoothDiscovery.restartScan()
    }
    //functions for communicating with device.
    let sendQueue = NSOperationQueue()
    let sendQueue2 = NSOperationQueue()
    //Intensity is on a scale of 0-100
    //Speed is on a scale of -100-100
    //Angle is on a scale of 0-180
    public func sendByteArray(toSend: NSData){
            if let serviceBLE = sharedBluetoothDiscovery.serviceBLE{
                sendQueue.addOperationWithBlock{
                    if(!self.allowSend){
                        NSThread.sleepForTimeInterval(self.sendInterval/2)
                    }
                    serviceBLE.setTX(toSend)
                    self.startTimerSend()
                }
            }
            else{
                dbg_print("service not avaliable when trying to send message")
            }
    }
    
    public func recieveByteArray()-> NSData{
        if let serviceBLE = sharedBluetoothDiscovery.serviceBLE{
            let value = serviceBLE.getValues()
            dbg_print(NSString(format: "got data: %@", value))
            if (value.length >= 4){
                return value
            }
            else{
                return NSData()
            }
        }
        else{
            dbg_print("service not avaliable when trying to get message")
            return NSData()
        }
    }
    
    public func setLED(port: UInt8, intensity: UInt8){
        let realPort = Int(port-1)
        if(leds[realPort] == intensity){
            return;
        }
        let command: NSData = getLEDCommand(port, intensity: intensity)
        leds[realPort] = intensity
        self.sendByteArray(command)
    }
    
    public func setTriLED(port: UInt8, r: UInt8, g: UInt8, b: UInt8){
        let realPort = Int(port-1)
        if(trileds[realPort] == [r,g,b]){
            return;
        }
        let command: NSData = getTriLEDCommand(port, redVal: r, greenVal: g, blueVal: b)
        trileds[realPort] = [r,g,b]
        self.sendByteArray(command)
    }
    
    public func setMotor(port: UInt8, speed: Int){
        let realPort = Int(port-1)
        if(motors[realPort] == speed){
            return
        }
        let command: NSData = getMotorCommand(port, speed: speed)
        motors[realPort] = speed
        self.sendByteArray(command)
    }
    
    public func setVibration(port: UInt8, intensity: UInt8){
        let realPort = Int(port-1)
        if(vibrations[realPort] == intensity){
            return
        }
        let command: NSData = getVibrationCommand(port, intensity: intensity)
        vibrations[realPort] = intensity
        self.sendByteArray(command)
    }
    
    public func setServo(port: UInt8, angle: UInt8){
        let realPort = Int(port-1)
        if(servos[realPort] == angle){
            return
        }
        let command: NSData = getServoCommand(port, angle: angle)
        servos[realPort] = angle
        self.sendByteArray(command)
    }
    
    public func resetHummingBird(){
        self.sendByteArray(getResetCommand())
    }
    
    public func turnOffLightsMotor(){
        self.sendByteArray(getTurnOffCommand())
    }
    
    public func getAllSensorData() ->[UInt8]{
        self.sendByteArray(getPollSensorsCommand())
        NSThread.sleepForTimeInterval(readInterval)
        var values: [UInt8] = lastKnowSensorPoll
        let result = self.recieveByteArray()
        if (result.length > 0){
            result.getBytes(&values, range: NSMakeRange(0, 4))
            lastKnowSensorPoll = values
        }
        return values
    }
    
    public func getSensorData(port: UInt8) -> UInt8{
        let realPort = port-1
        let sensorData: [UInt8] = getAllSensorData()
        return sensorData[Int(realPort)]
    }
    
    public func beginPolling(){
        sendByteArray(getPollStartCommand())
    }
    public func stopPolling(){
        sendByteArray(getPollStopCommand())
    }
    public func getAllSensorDataFromPoll() ->[UInt8]{
        var values: [UInt8] = lastKnowSensorPoll
        let result = self.recieveByteArray()
        if (result.length > 0){
            result.getBytes(&values, range: NSMakeRange(0, 4))
            lastKnowSensorPoll = values
        }
        return values
    }
    public func getSensorDataFromPoll(port: UInt8) -> UInt8{
        let realPort = port-1
        let sensorData: [UInt8] = getAllSensorDataFromPoll()
        return sensorData[Int(realPort)]
    }
    
    public func setName(name: String){
        var adjustedName: String = name
        if (name.characters.count > 18){
            adjustedName = (name as NSString).substringToIndex(18)
        }
        let command1: NSData = StringToCommand("+++")//command mode
        let namePhrase: String = "AT+GAPDEVNAME="
        let command2_1: NSData = StringToCommandNoEOL(namePhrase)//name command
        let command2_2: NSData = StringToCommand(adjustedName) //set actual name
        let command3: NSData = StringToCommand("ATZ")//reset
        
        self.sendByteArray(command1)
        NSThread.sleepForTimeInterval(0.2)
        self.sendByteArray(command2_1)
        NSThread.sleepForTimeInterval(0.2)
        self.sendByteArray(command2_2)
        NSThread.sleepForTimeInterval(0.2)
        self.sendByteArray(command3)
        dbg_print("finished setting new name")
    }
    
    public func factoryReset(){
        let command1: NSData = StringToCommand("+++")//command mode
        let command2: NSData = StringToCommand("AT+FACTORYRESET")
        self.sendByteArray(command1)
        NSThread.sleepForTimeInterval(0.2)
        self.sendByteArray(command2)
    }
    
    func connectionChanged(notification: NSNotification){
        let userinfo = notification.userInfo as! [String: Bool]
        if let isConnected: Bool = userinfo["isConnected"]{
            let connectionDetails = ["isConnected" : isConnected]
            NSNotificationCenter.defaultCenter().postNotificationName(BluetoothStatusChangedNotification, object: self, userInfo: connectionDetails)
        }
    }

}