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
/**
:Class: HummingbirdServices

:Description: This class is used to manage the status of the hummingbird. It allows for checking the sensor ports and for setting all the different outputs of the hummingbird.
*/
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
    /**
        this is called when the send timer has elapsed   
    */
    func timerElapsedSend(){
        self.allowSend = true
        self.stopTimerSend()
    }
    /**
        this is called to manually stop the send timer
    */
    func stopTimerSend(){
        if self.timerDelaySend == nil{
            return
        }
        timerDelaySend?.invalidate()
        self.timerDelaySend = nil
    }
    /**
        starts the timer to keep track of when the last send request happened
    */
    func startTimerSend(){
        self.allowSend = false
        if (timerDelaySend == nil){
            timerDelaySend = NSTimer.scheduledTimerWithTimeInterval(sendInterval, target: self, selector: Selector("timerElapsedSend"), userInfo: nil, repeats: false)
        }
    }
 
    
    //functions for connected to a new device
    /**
        Gets a list of BLE devices that the discovery service has found
        
        :returns: [String:CBPeripheral] maping of the name of a device to the device
    */
    public func getAvailiableDevices() -> [String: CBPeripheral]{
        return sharedBluetoothDiscovery.getDiscovered()
    }
    /**
        Connects to a device using the bluetooth discovery service
    */
    public func connectToDevice(peripheral: CBPeripheral){
        sharedBluetoothDiscovery.connectToPeripheral(peripheral)
    }
    /**
        Disconnects from the device we are currently connected to
    */
    public func disconnectFromDevice(){
        sharedBluetoothDiscovery.disconnectFromPeripheral()
    }
    /**
        Restarts the scan for BLE devices
    */
    public func restartScan(){
        sharedBluetoothDiscovery.restartScan()
    }
    //functions for communicating with device.
    let sendQueue = NSOperationQueue()
    //let sendQueue2 = NSOperationQueue()
    //Intensity is on a scale of 0-100
    //Speed is on a scale of -100-100
    //Angle is on a scale of 0-180
    
    /**
        Sends a command to the hummingbird. This function is primarily used by other functions in this class to send more specific commands. 
    
        :param: toSend NSData the data being sent
    */
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
    /**
        Gets data from the hummingbird. This retrieves the latest message sent by the hummingbird over bluetooth
    
        :returns: NSData the latest data from the hummingbird
    */
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
    /**
        Sets an LED
    
        :param: port UInt8 The port of the LED, should be from 1-4
    
        :param: intensity UInt8 The intensity to set the LED to, should be from 0-100
    */
    public func setLED(port: UInt8, intensity: UInt8){
        let realPort = Int(port-1)
        if(leds[realPort] == intensity){
            return;
        }
        let command: NSData = getLEDCommand(port, intensity: intensity)
        leds[realPort] = intensity
        self.sendByteArray(command)
    }
    /**
        Sets the Tri-LED 
    
        :param: port UInt8 The port of the LED, should be from 1-2
    
        :param: r UInt8 The intensity of the red component of the LED, should be from 0-100
    
        :param: g UInt8 The intensity of the green component of the LED, should be from 0-100
    
        :param: b UInt8 The intensity of the blue component of the LED, should be from 0-100
    
    */
    public func setTriLED(port: UInt8, r: UInt8, g: UInt8, b: UInt8){
        let realPort = Int(port-1)
        if(trileds[realPort] == [r,g,b]){
            return;
        }
        let command: NSData = getTriLEDCommand(port, redVal: r, greenVal: g, blueVal: b)
        trileds[realPort] = [r,g,b]
        self.sendByteArray(command)
    }
    /**
        Sets the motor
    
        :param: port UInt8 The port of the motor, should be from 1-2
    
        :param: speed Int The speed of the motor, should be from -100 to 100
    */
    public func setMotor(port: UInt8, speed: Int){
        let realPort = Int(port-1)
        if(motors[realPort] == speed){
            return
        }
        let command: NSData = getMotorCommand(port, speed: speed)
        motors[realPort] = speed
        self.sendByteArray(command)
    }
    /**
        Sets vibration
    
        :param: port UInt8 The port of the vibrator, should be from 1-2
    
        :param: intensity UInt8 The intensity to set the vibrator to, should be from 0-100
    */
    public func setVibration(port: UInt8, intensity: UInt8){
        let realPort = Int(port-1)
        if(vibrations[realPort] == intensity){
            return
        }
        let command: NSData = getVibrationCommand(port, intensity: intensity)
        vibrations[realPort] = intensity
        self.sendByteArray(command)
    }
    /**
        Sets the servo
    
        :param: port UInt8 The port of the servo, should be from 1-4
    
        :param: angle UInt8 The angle to turn the servo too, should be from 0-180
    */
    public func setServo(port: UInt8, angle: UInt8){
        let realPort = Int(port-1)
        if(servos[realPort] == angle){
            return
        }
        let command: NSData = getServoCommand(port, angle: angle)
        servos[realPort] = angle
        self.sendByteArray(command)
    }
    /**
        Sends the reset command to the hummingbird
    */
    public func resetHummingBird(){
        self.sendByteArray(getResetCommand())
    }
    /**
        Sends a command to turn off all lights and motors to the hummingbird
    */
    public func turnOffLightsMotor(){
        self.sendByteArray(getTurnOffCommand())
    }
    /**
        Gets all sensor data by sending an explicit request for information and getting a response
    
        :returns: [UInt8] and array of length 4 where the ith value is the raw value of the i+1th sensor
    */
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
    /**
        Gets data for a single sensor by sending an explicit request for information and getting a response
    
        :param: port UInt8 the port of the sensor, should be from 1-4
    
        :returns: UInt8 the raw value of the sensor
    */
    public func getSensorData(port: UInt8) -> UInt8{
        let realPort = port-1
        let sensorData: [UInt8] = getAllSensorData()
        return sensorData[Int(realPort)]
    }
    /**
        Sends a command to the hummingbird to start polling the sensors. This will cause the hummingbird to constantly broadcast the values of all of its sensors
    */
    public func beginPolling(){
        sendByteArray(getPollStartCommand())
    }
    /**
        Sends a command to stop polling the sensors
    */
    public func stopPolling(){
        sendByteArray(getPollStopCommand())
    }
    /**
        This is used to get all of the sensor after polling has begun. beginPolling() MUST have been called in order for this function to properly get the sensor information
    */
    public func getAllSensorDataFromPoll() ->[UInt8]{
        var values: [UInt8] = lastKnowSensorPoll
        let result = self.recieveByteArray()
        if (result.length > 0){
            result.getBytes(&values, range: NSMakeRange(0, 4))
            lastKnowSensorPoll = values
        }
        return values
    }
    /**
        Gets data for a single sensor from the constant poll
    
        :param: port UInt8 the port of the sensor, should be from 1-4
    
        :returns: UInt8 the raw value of the sensor
    */
    public func getSensorDataFromPoll(port: UInt8) -> UInt8{
        let realPort = port-1
        let sensorData: [UInt8] = getAllSensorDataFromPoll()
        return sensorData[Int(realPort)]
    }
    /**
        Sets the name of the hummingbird's BLE module 
    
        :param: name String The new name of the hummingbird
    */
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
    /**
        Factory Resets the BLE module
    */
    public func factoryReset(){
        let command1: NSData = StringToCommand("+++")//command mode
        let command2: NSData = StringToCommand("AT+FACTORYRESET")
        self.sendByteArray(command1)
        NSThread.sleepForTimeInterval(0.2)
        self.sendByteArray(command2)
    }
    /**
        Used to pass notifications arround. Sends a notification on connection/disconnection
    */
    func connectionChanged(notification: NSNotification){
        let userinfo = notification.userInfo as! [String: Bool]
        if let isConnected: Bool = userinfo["isConnected"]{
            let connectionDetails = ["isConnected" : isConnected]
            NSNotificationCenter.defaultCenter().postNotificationName(BluetoothStatusChangedNotification, object: self, userInfo: connectionDetails)
        }
    }

}