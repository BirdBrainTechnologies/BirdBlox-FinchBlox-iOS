//
//  BBTRobotBLEPeripheral.swift
//  BirdBlox
//
//  Created by Jeremy Huang on 2017-07-17.
//  Copyright © 2017年 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import CoreBluetooth

class BBTRobotBLEPeripheral: NSObject, CBPeripheralDelegate {

    public let peripheral: CBPeripheral
    public let type: BBTRobotType
    private let BLE_Manager: BLECentralManager
	
    public var id: String {
        return self.peripheral.identifier.uuidString
    }
    public var connected: Bool {
        return peripheral.state == CBPeripheralState.connected
    }
    
    var rx_line, tx_line: CBCharacteristic?
    
    //static let sensorByteCount = 4  //TODO: Should this be different for finch?
    //private var lastSensorUpdate: [UInt8] = Array<UInt8>(repeating: 0, count: sensorByteCount)
    private var lastSensorUpdate: [UInt8]
    var sensorValues: [UInt8] {
        switch type {
        case .Hummingbird, .Finch, .HummingbirdBit, .MicroBit:
            return lastSensorUpdate
        case .Flutter:
            var response: String = sendDataWithResponse(data: BBTFlutterUtility.readCommand)
            var values = response.split(",")
            var counter = 0
            //this just gets the 0th character of values[0] (which should only be 1
            //character and checks to see if it is the flutter response char
            while(getUnicode(values[0][values[0].index(values[0].startIndex, offsetBy: 0)]) !=
                BBTFlutterUtility.responseCharacter) {
                    print("Got invalid response: " + response)
                    response = sendDataWithResponse(data: BBTFlutterUtility.readCommand)
                    values = response.split(",")
                    counter += 1
                    if counter >= MAX_RETRY {
                        print("failed to send read command")
                        break
                    }
            }
            
            let sp1 = UInt8(values[1])
            let sp2 = UInt8(values[2])
            let sp3 = UInt8(values[3])
            
            guard let sensorPercent1 = sp1,
                let sensorPercent2 = sp2,
                let sensorPercent3 = sp3 else {
                    return [0, 0, 0]
            }
            
            return [sensorPercent1, sensorPercent2, sensorPercent3]
        }
    }
    
    private let initializationCompletion: ((BBTRobotBLEPeripheral) -> Void)?
    private var _initialized = false
    public var initialized: Bool {
        return self._initialized
    }
    
    //MARK: Variables to coordinate set all
    private var useSetall = true
    private var writtenCondition: NSCondition = NSCondition()
    
    //MARK: Variables write protected by writtenCondition
    //private var currentOutputState: BBTHummingbirdOutputState
    //public var nextOutputState: BBTHummingbirdOutputState
    private var currentOutputState: BBTRobotOutputState
    public var nextOutputState: BBTRobotOutputState
    var lastWriteWritten: Bool = false
    var lastWriteStart: DispatchTime = DispatchTime.now()
    //End variables write protected by writtenCondition
    private var syncTimer: Timer = Timer()
    let syncInterval = 0.03125 //(32Hz) TODO: should this be 0.017 (60Hz) for finch?
    let cacheTimeoutDuration: UInt64 = 1 * 1_000_000_000 //nanoseconds
    let waitRefreshTime = 0.5 //seconds
    
    let creationTime = DispatchTime.now()
    
    private var initializingCondition = NSCondition()
    private var lineIn: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0]
    private var hardwareString = ""
    private var firmwareVersionString = ""
    
    //MARK: Variables for HB renaming
    //    static let ADALE_COMMAND_MODE_TOGGLE = "+++\n"
    //    static let ADALE_GET_MAC = "AT+BLEGETADDR\n"
    //    static let ADALE_SET_NAME = "AT+GAPDEVNAME="
    //    static let ADALE_RESET = "ATZ\n"
    //    static let NAME_PREFIX = "HB"
    //    var macStr: String? = nil
    //    let macReplyLen = 17e
    //    let macLen = 12
    //    var oneOffTimer: Timer = Timer()
    //    var resettingName = false
    //    var gettingMAC = false
    //    var commandMode = false
    
    override public var description: String {
        let gapName = self.peripheral.name ?? "Unknown"
        let name = BBTgetDeviceNameForGAPName(gapName)
        
        var updateDesc = ""
        if !self.useSetall {
            updateDesc = "\n\nThis \(type.description) needs to be updated. " +
                "See the link below: \n" +
            "http://www.hummingbirdkit.com/learning/installing-birdblox#BurnFirmware "
        }
        
        return
            "\(type.description) Peripheral\n" +
                "Name: \(name)\n" +
                "Bluetooth Name: \(gapName)\n" +
                "Hardware Version: \(self.hardwareString)\n" +
                "Firmware Version: \(self.firmwareVersionString)" +
        updateDesc
    }
    
    //MARK: Flutter only variables
    var rx_config_line: CBDescriptor?
    private var data_cond: NSCondition = NSCondition()
    
    private var servos: [UInt8] = [0,0,0]
    private var servos_time: [Double] = [0,0,0]
    private var trileds: [[UInt8]] = [[0,0,0],[0,0,0],[0,0,0]]
    private var trileds_time: [Double] = [0,0,0]
    private var buzzerVolume: Int = 0
    private var buzzerFrequency: Int = 0
    private var buzzerTime: Double = 0
    
    let OK_RESPONSE = "OK"
    let FAIL_RESPONSE = "FAIL"
    let MAX_RETRY = 50
    
    let cache_timeout: Double = 15.0 //in seconds
    
    //MARK: INIT
    
    required init(_ peripheral: CBPeripheral, _ type: BBTRobotType, _ completion: ((BBTRobotBLEPeripheral) -> Void)? = nil){
        self.peripheral = peripheral
        self.type = type
        self.BLE_Manager = BLECentralManager.shared
        
        lastSensorUpdate = Array<UInt8>(repeating: 0, count: type.sensorByteCount)
        
        /*
        switch type {
        case .Hummingbird:
            self.currentOutputState = BBTHummingbirdOutputState()
            self.nextOutputState = BBTHummingbirdOutputState()
        case .Finch:
            self.currentOutputState = BBTFinchOutputState()
            self.nextOutputState = BBTFinchOutputState()
        case .Flutter:
            self.currentOutputState = BBTFlutterOutputState()
            self.nextOutputState = BBTFlutterOutputState()
        case .HummingbirdBit:
            self.currentOutputState = BBTHummingbirdBitOutputState()
            self.nextOutputState = BBTHummingbirdBitOutputState()
        case .MicroBit:
            self.currentOutputState = BBTMicroBitOutputState()
            self.nextOutputState = BBTMicroBitOutputState()
        }*/
        self.currentOutputState = BBTRobotOutputState(robotType: type)
        self.nextOutputState = BBTRobotOutputState(robotType: type)
        
        self.initializationCompletion = completion
        
        super.init()
        
        self.peripheral.delegate = self
        self.peripheral.discoverServices([type.SERVICE_UUID])
    }

    
    //MARK: Peripheral Delegate Methods
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
                if(service.uuid == type.SERVICE_UUID){
                    peripheral.discoverCharacteristics([type.RX_UUID,
                                                        type.TX_UUID],
                                                       for: service)
                    return
                }
            }
        }
    }
    
    /**
     * Once we find a characteristic, we check if it is the RX or TX line that was
     * found. Once we have found both, we send a notification saying the device
     * is now connected if hummingbird or we begin looking for descriptors if flutter
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
                if(characteristic.uuid == type.TX_UUID){
                    tx_line = characteristic
                    peripheral.setNotifyValue(true, for: characteristic )
                    wasTXSet = true
                }
                else if(characteristic.uuid == type.RX_UUID){
                    rx_line = characteristic
                    peripheral.setNotifyValue(true, for: characteristic )
                    wasRXSet = true
                }
                if(wasTXSet && wasRXSet){
                    switch type{ //TODO: merge initialize functions
                    case .Hummingbird, .HummingbirdBit, .MicroBit:
                        DispatchQueue.main.async {
                            self.initializeHB()
                        }
                        return
                    case .Finch:
                        DispatchQueue.main.async {
                            self.initializeFN()
                        }
                        return
                    case .Flutter:
                        peripheral.discoverDescriptors(for: rx_line!)
                        return
                    }
                    
                }
            }
        }
    }
    private func initializeHB() {
        print("start init")
        //Get ourselves a fresh slate
        //self.sendData(data: BBTHummingbirdUtility.getPollStopCommand())
        self.sendData(data: type.command("pollStop"))
        //        Thread.sleep(forTimeInterval: 4) //make sure that the HB is booted up
        //Worked 4 of 5 times when at 3 seconds.
        
        let timeoutTime = Date(timeIntervalSinceNow: TimeInterval(7)) //seconds
        
        self.initializingCondition.lock()
        let oldLineIn = self.lineIn
        self.sendData(data: "G4".data(using: .utf8)!)
        
        //Wait until we get a response or until we timeout.
        //If we time out the verion will be 0.0, which is invalid.
        while (self.lineIn == oldLineIn && (Date().timeIntervalSince(timeoutTime) < 0)) {
            self.initializingCondition.wait(until: Date(timeIntervalSinceNow: 1))
        }
        let versionArray = self.lineIn
        
        
        self.hardwareString = String(versionArray[0]) + "." + String(versionArray[1])
        self.firmwareVersionString = String(versionArray[2]) + "." + String(versionArray[3]) +
            (String(bytes: [versionArray[4]], encoding: .ascii) ?? "")
        
        print(versionArray)
        print("end hi")
        self.initializingCondition.unlock()
        
        
        guard self.connected else {
            BLE_Manager.disconnect(byID: self.id)
            NSLog("Initialization failed because HB got disconnected.")
            return
        }
        
        //If the firmware version is too low, then disconnect and inform the user.
        //Must be higher than 2.2b OR be 2.1i
        guard versionArray[2] >= 2 &&
            ((versionArray[3] >= 2) || (versionArray[3] == 1 && versionArray[4] >= 105)) else {
                let _ = FrontendCallbackCenter.shared
                    .robotFirmwareIncompatible(id: self.id, firmware: self.firmwareVersionString)
                
                BLE_Manager.disconnect(byID: self.id)
                NSLog("Initialization failed due to incompatible firmware.")
                return
        }
        
        //Old firmware, but still compatible
        if versionArray[3] == 1 && versionArray[4] >= 105 {
            let _ = FrontendCallbackCenter.shared.robotFirmwareStatus(id: self.id, status: "old")
            self.useSetall = false
        }
        
        
        Thread.sleep(forTimeInterval: 0.1)
        //self.sendData(data: BBTHummingbirdUtility.getPollStartCommand())
        self.sendData(data: type.command("pollStart"))
        
        //        DispatchQueue.main.async{
        if self.useSetall {
            self.syncTimer =
                Timer.scheduledTimer(timeInterval: self.syncInterval, target: self,
                                     selector: #selector(syncronizeOutputs),
                                     userInfo: nil, repeats: true)
            self.syncTimer.fire()
        }
        //        }
        
        self._initialized = true
        print("Hummingbird initialized")
        if let completion = self.initializationCompletion {
            completion(self)
        }
    }
    private func initializeFN() {
        print("start init")
        //Get ourselves a fresh slate
        self.sendData(data: "BS".data(using: .ascii)!)
        Thread.sleep(forTimeInterval: 0.5) //
        self.sendData(data: "BG".data(using: .ascii)!)
        
        DispatchQueue.main.async {
            print("starting timer")
            self.syncTimer =
                Timer.scheduledTimer(timeInterval: self.syncInterval, target: self,
                                     selector: #selector(self.syncronizeOutputs),
                                     userInfo: nil, repeats: true)
            self.syncTimer.fire()
        }
        
        self._initialized = true
        print("Finch initialized")
        if let completion = self.initializationCompletion {
            completion(self)
        }
    }
    
    /**
     * We want a specific characteristic on the RX line that is used for data
     * This method is only used for Flutter
     */
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        if (peripheral != self.peripheral || error != nil || characteristic != rx_line!) {
            //not the right device
            return
        }
        if let descriptors = characteristic.descriptors {
            for descriptor in descriptors {
                if descriptor.uuid == type.RX_CONFIG_UUID {
                    rx_config_line = descriptor
                    peripheral.setNotifyValue(true, for: rx_line!)
                    self.initializeFlutter()
                    return
                }
            }
        }
    }
    private func initializeFlutter() {
        self._initialized = true
        //        print(self.sendDataWithResponse(data: "G4".data(using: .ascii)!))
        print("flutter initialized")
        if let completion = self.initializationCompletion {
            completion(self)
        }
    }
    
    /**
     * Called when a descriptor is updated
     * Also only used for Flutter
     */
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        if descriptor != rx_config_line {
            return
        }
        print((descriptor.value as! Data?) ?? "nil update flutter")
        data_cond.lock()
        data_cond.signal()
        data_cond.unlock()
    }
    
    /**
     *
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if error != nil {
            NSLog(error.debugDescription)
            return
        }
        
        switch type {
        case .Hummingbird, .HummingbirdBit, .MicroBit, .Finch:
            //If we are trying to reset the hummingbird's name, this should be the device's MAC
            //        print("Did update characteristic \(characteristic)")
            //print("\(characteristic.value!.count) \(characteristic)")
            
            if characteristic.uuid != type.RX_UUID {
                return
            }
            
            guard let inData = characteristic.value else {
                return
            }
            
            guard self.initialized else {
                self.initializingCondition.lock()
                print("hi")
                print(inData.debugDescription)
                inData.copyBytes(to: &self.lineIn, count: self.lineIn.count)
                self.initializingCondition.signal()
                self.initializingCondition.unlock()
                return
            }
            
            if characteristic.value!.count % 5 != 0 {
                return
            }
            
            //print(inData.debugDescription)
            //print("\(lastSensorUpdate[0]) \(lastSensorUpdate[1]) \(lastSensorUpdate[2]) \(lastSensorUpdate[3]) ")
            //print(lastSensorUpdate)
            
            //Assume it's sensor in data
            inData.copyBytes(to: &self.lastSensorUpdate, count: type.sensorByteCount)
        case .Flutter:
            if characteristic != tx_line {
                return
            }
            data_cond.lock()
            data_cond.signal()
            data_cond.unlock()
            /*
        case .Finch:
            guard let inData = characteristic.value else {
                return
            }
            
            //Assume it's sensor in data
            inData.copyBytes(to: &self.lastSensorUpdate, count: 10)*/
        }
    }
    
    /**
     * Called when we update a characteristic (when we write to the HB or finch)
     */
    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            NSLog("Unable to write to \(type.description) due to error \(error)")
        }
        
        //        print("did write")
        
        //We successfully sent a command
        self.writtenCondition.lock()
        self.lastWriteWritten = true
        self.writtenCondition.signal()
        
        //        self.currentOutputState = self.nextOutputState.immutableCopy
        
        self.writtenCondition.unlock()
        //        print(self.lastWriteStart)
    }
    
    //MARK: Misc. functions
    
    public func endOfLifeCleanup() -> Bool{
        switch type {
        case .Hummingbird, .Finch, .HummingbirdBit, .MicroBit:
            //        self.sendData(data: BBTHummingbirdUtility.getPollStopCommand())
            self.syncTimer.invalidate()
        case .Flutter: ()
        }
        return true
    }
    
    //Hummingbird and finch function
    private func sendData(data: Data) {
        if self.connected {
            peripheral.writeValue(data, for: tx_line!, type: .withResponse)
            
            //            if self.commandMode {
            //                print("Sent command: " +
            //                    (NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String))
            //            }
            //            else {
            ////                print("Sent non-command mode message")
            //            }
        }
        else{
            print("Not connected")
        }
    }
    
    //flutter function
    func sendDataWithResponse(data: Data) -> String {
        guard let tx_line = self.tx_line else {
            NSLog("Has not discovered tx line yet.")
            return FAIL_RESPONSE
        }
        
        data_cond.lock()
        peripheral.writeValue(data, for: tx_line, type: .withResponse)
        //peripheral.writeValue(data, for: rx_config_line!)
        data_cond.wait(until: Date(timeIntervalSinceNow: 0.2))
        data_cond.unlock()
        
        let response = tx_line.value
        if let safe_response = response,
            let data_string = String(data: safe_response, encoding: .utf8) {
            return data_string
        }
        return FAIL_RESPONSE
    }
    //flutter function
    func sendDataWithoutResponse(data: Data) {
        var response: String? = FAIL_RESPONSE
        var counter = 0
        while(response != OK_RESPONSE) {
            response = sendDataWithResponse(data: data)
            counter += 1
            if counter >= MAX_RETRY {
                let dataArray = [UInt8](data)
                print("failed to send data: \(dataArray)")
                return
            }
        }
    }
    //hummingbird and finch function
    private func conditionHelper(condition: NSCondition, holdLock: Bool = true,
                                 predicate: (() -> Bool), work: (() -> ())) {
        if holdLock {
            condition.lock()
        }
        
        while !predicate() {
            condition.wait(until: Date(timeIntervalSinceNow: self.waitRefreshTime))
        }
        
        work()
        
        condition.signal()
        if holdLock {
            condition.unlock()
        }
    }
    
    //TODO: (finch) add a check for legacy firmware and use set all for only
    //firmwares newer than 2.2.a
    //From Tom: send the characters 'G' '4' and you will get back the hardware version
    //(currently 0x03 0x00) and the firmware version (0x02 0x02 'b'), might be 'a' instead of 'b'
    
    //MARK: Robot outputs
    func setLED(port: Int, intensity: UInt8) -> Bool {
        
        //Neither finch nor flutter have regular leds
        //if type == .Flutter || type == .Finch {
        //    return false
        //}
        
        //if there are fewer leds than the port number specified
        if self.type.ledCount < port {
            return false
        }
        
        guard self.peripheral.state == .connected else {
            return false
        }
        guard self.useSetall else {
            self.sendData(data: BBTHummingbirdUtility.getLEDCommand(UInt8(port),
                                                                    intensity: intensity))
            Thread.sleep(forTimeInterval: 0.1)
            return true
        }
        
        let i = port - 1
        
        self.writtenCondition.lock()
        
        self.conditionHelper(condition: self.writtenCondition, holdLock: false,
                             predicate: {
                                self.nextOutputState.leds![i] == self.currentOutputState.leds![i]
        }, work: {
            self.nextOutputState.leds![i] = intensity
        })
        
        self.writtenCondition.unlock()
        
        print("exit")
        return true
    }
    
    func setTriLED(port: UInt, intensities: BBTTriLED) -> Bool {
        
        if self.type.triledCount < port {
            return false
        }
        guard self.peripheral.state == .connected else {
            return false
        }
        
        switch type {
        case .Hummingbird, .Finch, .HummingbirdBit:
            guard self.useSetall else {
                let command = BBTHummingbirdUtility.getTriLEDCommand(UInt8(port),
                                                                     red_val: intensities.red,
                                                                     green_val: intensities.green,
                                                                     blue_val: intensities.blue)
                self.sendData(data: command)
                Thread.sleep(forTimeInterval: 0.1)
                return true
            }
            
            let i = Int(port - 1)
            let (r, g, b) = (intensities.red, intensities.green, intensities.blue)
            
            self.writtenCondition.lock()
            
            self.conditionHelper(condition: self.writtenCondition, holdLock: false,
                                 predicate: {
                                    self.nextOutputState.trileds![i] == self.currentOutputState.trileds![i]
            }, work: {
                self.nextOutputState.trileds![i] = BBTTriLED(red: r, green: g, blue: b)
            })
            
            self.writtenCondition.unlock()
            return true
        case .Flutter:
            let i = Int(port - 1)
            let (r, g, b) = (intensities.red, intensities.green, intensities.blue)
            let current_time = NSDate().timeIntervalSince1970
            if(trileds[i] == [r,g,b] && (current_time - trileds_time[i]) < cache_timeout){
                print("triled command not sent because it has been cached.")
                return true //Still successful in getting LED to be the right value
            }
            let command = BBTFlutterUtility.ledCommand(UInt8(port), r: r, g: g, b: b)
            self.sendDataWithoutResponse(data: command)
            trileds[i] = [r,g,b]
            trileds_time[i] = current_time
            
            //        print("triled command sent \(r) \(g) \(b)")
            
            return true
        case .MicroBit:
            return false
        }
    }
    
    func setVibration(port: Int, intensity: UInt8) -> Bool {
        
        if self.type.vibratorCount < port {
            return false
        }
        guard self.peripheral.state == .connected else {
            return false
        }
        guard self.useSetall else {
            let command = BBTHummingbirdUtility.getVibrationCommand(UInt8(port),
                                                                    intensity: intensity)
            self.sendData(data: command)
            Thread.sleep(forTimeInterval: 0.1)
            return true
        }
        
        let i = port - 1
        
        self.writtenCondition.lock()
        
        self.conditionHelper(condition: self.writtenCondition, holdLock: false,
                             predicate: {
                                self.nextOutputState.vibrators![i] == self.currentOutputState.vibrators![i]
        }, work: {
            self.nextOutputState.vibrators![i] = intensity
        })
        
        self.writtenCondition.unlock()
        
        
        return true
    }
    
    func setMotor(port: Int, speed: Int8) -> Bool {
        
        //flutter does not have motors
        //if type == .Flutter || type == .MicroBit || type == .HummingbirdBit {
        //    return false
        //}
        if self.type.motorCount < port {
            return false
        }
        guard self.peripheral.state == .connected else {
            return false
        }
        guard self.useSetall else {
            let command = BBTHummingbirdUtility.getMotorCommand(UInt8(port),
                                                                speed: Int(speed))
            self.sendData(data: command)
            Thread.sleep(forTimeInterval: 0.1)
            return true
        }
        
        let i = port - 1
        
        self.writtenCondition.lock()
        
        self.conditionHelper(condition: self.writtenCondition, holdLock: false,
                             predicate: {
                                self.nextOutputState.motors![i] == self.currentOutputState.motors![i]
        }, work: {
            self.nextOutputState.motors![i] = speed
        })
        
        self.writtenCondition.unlock()
        
        
        return true
    }
    
    func setServo(port: UInt, angle: UInt8) -> Bool {
        
        if self.type.servoCount < port {
            return false
        }
        guard self.peripheral.state == .connected else {
            return false
        }
        switch type {
        case .Hummingbird, .Finch, .HummingbirdBit:
            guard self.useSetall else {
                let command = BBTHummingbirdUtility.getServoCommand(UInt8(port),
                                                                    angle: angle)
                self.sendData(data: command)
                Thread.sleep(forTimeInterval: 0.1)
                return true
            }
            
            let i = Int(port - 1)
            
            self.writtenCondition.lock()
            
            self.conditionHelper(condition: self.writtenCondition, holdLock: false,
                                 predicate: {
                                    self.nextOutputState.servos![i] == self.currentOutputState.servos![i]
            }, work: {
                self.nextOutputState.servos![i] = angle
            })
            
            self.writtenCondition.unlock()
            return true
        case .Flutter:
            let i = Int(port - 1)
            let current_time = NSDate().timeIntervalSince1970
            if(servos[i] == angle && (current_time - servos_time[i]) < cache_timeout){
                return true //Still successful in getting output to be the right value
            }
            let command: Data = BBTFlutterUtility.servoCommand(UInt8(port), angle: angle)
            servos[i] = angle
            servos_time[i] = current_time
            self.sendDataWithoutResponse(data: command)
            return true
        case .MicroBit:
            return false
        }
    }
    
    func setBuzzer(volume: Int, frequency: Int) -> Bool {
        
        if self.type.buzzerCount != 1 {
            return false
        }
        switch type {
        case .Hummingbird, .Finch, .HummingbirdBit, .MicroBit:
            return false //TODO: add hummingbird buzzer!
        case .Flutter:
            let current_time = NSDate().timeIntervalSince1970
            if(buzzerVolume == volume &&
                buzzerFrequency == frequency &&
                (current_time - buzzerTime) < cache_timeout){
                return true //Still successful in getting output to be the right value
            }
            
            let command: Data = BBTFlutterUtility.buzzerCommand(vol: volume, freq: frequency)
            
            buzzerVolume = volume
            buzzerFrequency = frequency
            buzzerTime = current_time
            
            self.sendDataWithoutResponse(data: command)
            return true
        }
    }
    
    //TODO: Finch only??
    var allStr = "0,0,0,0,0,0,0,0,0,0,0,0,0,0"
    var lastStr = "0,0,0,0,0,0,0,0,0,0,0,0,0,0"
    func setAll(str: String) -> [UInt8] {
        self.writtenCondition.lock()
        self.allStr = str
        self.writtenCondition.unlock()
        return self.lastSensorUpdate
    }
    
    //TODO: Is this only for Hummingbird? The finch version was a little different. I deleted it.
    func syncronizeOutputs() {
        self.writtenCondition.lock()
        
        //        print("s ", separator: "", terminator: "")
        
        let nextCopy = self.nextOutputState
        
        let changeOccurred = !(nextCopy == self.currentOutputState)
        let currentCPUTime = DispatchTime.now().uptimeNanoseconds
        let timeout = ((currentCPUTime - self.lastWriteStart.uptimeNanoseconds) >
            self.cacheTimeoutDuration)
        let shouldSync = changeOccurred || timeout
        
        if self.initialized && (self.lastWriteWritten || timeout)  && shouldSync {
            /*
            var command = Data()
            
            switch type {
            case .Hummingbird:
                
                /*
                let cmdMkr = BBTHummingbirdUtility.getSetAllCommand
                
                guard let tris = nextCopy.trileds, let leds = nextCopy.leds, let servos = nextCopy.servos, let motors = nextCopy.motors, let vibrators = nextCopy.vibrators else {
                    fatalError("Stuff missing from robot output state!")
                }
                command = cmdMkr((tris[0].tuple, tris[1].tuple),
                                     (leds[0], leds[1], leds[2], leds[3]),
                                     (servos[0], servos[1], servos[2], servos[3]),
                                     (motors[0], motors[1]),
                                     (vibrators[0], vibrators[1]))
                */
                command = nextCopy.setAllCommand()
                
            case .Finch, .Flutter, .HummingbirdBit, .MicroBit: ()
                
            }*/
            
            let command = nextCopy.setAllCommand()
            self.sendData(data: command)
            self.lastWriteStart = DispatchTime.now()
            self.lastWriteWritten = false
            
            self.currentOutputState = nextCopy
            
            //For debugging
            #if DEBUG
                let bytes = UnsafeMutableBufferPointer<UInt8>(
                    start: UnsafeMutablePointer<UInt8>.allocate(capacity: 20), count: 19)
                let _ = command.copyBytes(to: bytes)
                print("\(self.creationTime)")
                print("Setting All: \(bytes.map({return $0}))")
            #endif
        }
        else {
            if !self.lastWriteWritten {
                //                print("miss")
            }
        }
        
        self.writtenCondition.unlock()
    }
    
    func setAllOutputsToOff() -> Bool {
        switch type {
        case .Hummingbird, .Finch, .HummingbirdBit, .MicroBit:
            //Sending an ASCII capital X should do the same thing.
            //Useful for legacy firmware
            
            self.writtenCondition.lock()
            self.nextOutputState = BBTRobotOutputState(robotType: type)
            self.writtenCondition.unlock()
        case .Flutter:
            //The order of output to shut off are: buzzer, servos, LEDs
            //Beware of shortcuts in boolean logic
            //Sending an ASCII capital X should do the same thing
            
            //        var suc = true
            //        suc = self.setBuzzer(volume: 0, frequency: 0) && suc
            //        for i in UInt(1)...3 {
            //            suc = self.setServo(port: i, angle: BBTFlutterUtility.servoOffAngle) && suc
            //        }
            //        for i in UInt(1)...3 {
            //            suc = self.setTriLED(port: i, intensities: BBTTriLED(0, 0, 0)) && suc
            //        }
            
            self.sendDataWithoutResponse(data: BBTFlutterUtility.turnOffCommand)
        }
        return true
    }
    
    //MARK: Flutter only functions
    
    func get (port: Int, input_type: String) -> Int? {
        let percent = self.sensorValues[port - 1]
        
        let value = percentToRaw(percent)
        
        switch input_type {
        case "distance":
            return rawToDistance(value)
        case "temperature":
            print("temp sensor \(value)")
            print("rtt \(rawToTemp(value))")
            return rawToTemp(value)
        case "soil":
            return bound(Int(percent), min: 0, max: 90)
        default:
            return Int(percent)
        }
    }
}
