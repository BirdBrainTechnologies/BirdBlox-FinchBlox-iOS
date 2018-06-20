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
    var sensorValues: [UInt8] { return lastSensorUpdate }
    
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
    //let syncInterval = 0.06
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
    
    //MARK: INIT
    
    required init(_ peripheral: CBPeripheral, _ type: BBTRobotType, _ completion: ((BBTRobotBLEPeripheral) -> Void)? = nil){
        self.peripheral = peripheral
        self.type = type
        self.BLE_Manager = BLECentralManager.shared
        
        lastSensorUpdate = Array<UInt8>(repeating: 0, count: type.sensorByteCount)
        
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
     * is now connected
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
                    case .Hummingbird, .HummingbirdBit, .MicroBit, .Flutter:
                        DispatchQueue.main.async {
                            self.initializeHB()
                        }
                        return
                    case .Finch:
                        DispatchQueue.main.async {
                            self.initializeFN()
                        }
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
        self.sendData(data: type.sensorCommand("pollStop"))
        //        Thread.sleep(forTimeInterval: 4) //make sure that the HB is booted up
        //Worked 4 of 5 times when at 3 seconds.
        
        //Check firmware version.
        //TODO: Check firmware for other robots.
        if type == .Hummingbird {
        
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
            //print("end hi")
            self.initializingCondition.unlock()
            
            
            guard self.connected else {
                BLE_Manager.disconnect(byID: self.id)
                NSLog("Initialization failed because HB got disconnected.")
                return
            }
            
            //TODO: Handle different min firmwares for different robot types
            //TODO: I don't think this is working properly. On a bluefruit adapter (HB88756) I got the version
            // array: [143, 153, 148, 135, 132, 0, 0, 0] and sometimes didn't get anything and the
            // whole program crashed.
            //If the firmware version is too low, then disconnect and inform the user.
            //Must be higher than 2.2b OR be 2.1i
            guard versionArray[2] >= 2 &&
                ((versionArray[3] >= 2) || (versionArray[3] == 1 && versionArray[4] >= 105)) else {
                    let _ = FrontendCallbackCenter.shared
                        .robotFirmwareIncompatible(robotType: type, id: self.id, firmware: self.firmwareVersionString)
                    
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
        }
        
        //self.sendData(data: BBTHummingbirdUtility.getPollStartCommand())
        self.sendData(data: type.sensorCommand("pollStart"))
        
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
     *
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if error != nil {
            NSLog(error.debugDescription)
            return
        }
        
        //If we are trying to reset the hummingbird's name, this should be the device's MAC
        //print("Did update characteristic \(characteristic)")
        //print("\(characteristic.value!.count) \(characteristic)")
        
        if characteristic.uuid != type.RX_UUID {
            return
        }
        
        guard let inData = characteristic.value else {
            return
        }
        
        //This block used for getting the firmware info
        guard self.initialized else {
            self.initializingCondition.lock()
            //print("hi")
            print(inData.debugDescription)
            inData.copyBytes(to: &self.lineIn, count: self.lineIn.count)
            self.initializingCondition.signal()
            self.initializingCondition.unlock()
            return
        }
            
        //var bytes = Array(repeating: 0 as UInt8, count: inData.count)
        //inData.copyBytes(to: &bytes, count: inData.count)
        //print("byte count: \(characteristic.value!.count), bytes: \(bytes)")
        
        //TODO: Why is this? Hummingbird duo seems to send a lot
        //of different length messages. Are they for different things?
        if type == .Hummingbird && characteristic.value!.count % 5 != 0 {
            print("Characteristic value \(characteristic.value!.count) not divisible by 5.")
            return
        }
        
        //print(inData.debugDescription)
        //print("\(lastSensorUpdate[0]) \(lastSensorUpdate[1]) \(lastSensorUpdate[2]) \(lastSensorUpdate[3]) ")
        //print(characteristic.value?.description)
        //print(lastSensorUpdate)
        
        //Assume it's sensor in data
        inData.copyBytes(to: &self.lastSensorUpdate, count: type.sensorByteCount)
    }
    
    /**
     * Called when we update a characteristic (when we write to the HB or finch)
     */
    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            NSLog("Unable to write to \(type.description) due to error \(error)")
        }
        
        NSLog("Did write value.")
        
        //We successfully sent a command
        self.writtenCondition.lock()
        self.lastWriteWritten = true
        self.writtenCondition.signal()
        
        //        self.currentOutputState = self.nextOutputState.immutableCopy
        
        self.writtenCondition.unlock()
        //        print(self.lastWriteStart)
    }
    
    /**
     * When the MicroBit is disconnected from or connected to the Hummingbird, it updates its name
     * This function does not ever seem to be called??
     */
    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        print("Name updated to \(peripheral.name ?? "unknown")")
    }
    
    //MARK: Misc. functions
    
    public func endOfLifeCleanup() -> Bool{
        //        self.sendData(data: BBTHummingbirdUtility.getPollStopCommand())
        self.syncTimer.invalidate()
        return true
    }
    
    
    private func sendData(data: Data) {
        if self.connected {
            //peripheral.writeValue(data, for: tx_line!, type: .withResponse)
            peripheral.writeValue(data, for: tx_line!, type: .withoutResponse)
            
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
        
        //if there are fewer leds than the port number specified
        if self.type.ledCount < port {
            return false
        }
        guard self.peripheral.state == .connected else {
            return false
        }
        
        guard self.useSetall else {
            guard let command = type.ledCommand(UInt8(port), intensity: intensity) else {
                return false
            }
            self.sendData(data: command)
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
        return true
    }
    
    func setTriLED(port: UInt, intensities: BBTTriLED) -> Bool {
        
        if self.type.triledCount < port {
            return false
        }
        guard self.peripheral.state == .connected else {
            return false
        }
        
        guard self.useSetall else {
            guard let command = type.triLEDCommand(UInt8(port), red_val: intensities.red, green_val: intensities.green, blue_val: intensities.blue) else {
                return false
            }
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
    }
    
    func setVibration(port: Int, intensity: UInt8) -> Bool {
        
        if self.type.vibratorCount < port {
            return false
        }
        guard self.peripheral.state == .connected else {
            return false
        }
        guard self.useSetall else {
            guard let command = type.vibrationCommand(UInt8(port), intensity: intensity) else {
                return false
            }
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
        
        if self.type.motorCount < port {
            return false
        }
        guard self.peripheral.state == .connected else {
            return false
        }
        
        guard self.useSetall else {
            guard let command = type.motorCommand(UInt8(port), speed: Int(speed)) else {
                return false
            }
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
    
    func setServo(port: UInt, value: UInt8) -> Bool {
        print("setting servo to \(value)")
        if self.type.servoCount < port {
            return false
        }
        guard self.peripheral.state == .connected else {
            return false
        }
        
        guard self.useSetall else {
            //TODO: value now adjusted in robotRequest. make change here if we are going to use this.
            guard let command = type.servoCommand(UInt8(port), angle: value) else {
                return false
            }
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
            self.nextOutputState.servos![i] = value
        })
        
        self.writtenCondition.unlock()
        return true
    }
    
    func setBuzzer(volume: Int, frequency: Int, period: UInt16, duration: UInt16) -> Bool {
        
        if self.type.buzzerCount != 1 {
            return false
        }
        guard self.peripheral.state == .connected else {
            return false
        }
        
        guard self.useSetall else {
            guard let command = type.buzzerCommand(period: period, dur: duration) else {
                return false
            }
            self.sendData(data: command)
            Thread.sleep(forTimeInterval: 0.1)
            return true
        }
        
        self.writtenCondition.lock()
        
        self.conditionHelper(condition: self.writtenCondition, holdLock: false,
                             predicate: {
                                self.nextOutputState.buzzer! == self.currentOutputState.buzzer!
        }, work: {
            self.nextOutputState.buzzer = BBTBuzzer(freq: 0, vol: 0, period: period, duration: duration)
        })
        
        self.writtenCondition.unlock()
        return true
    }
    
    func setLedArray(_ statusString: String) -> Bool {
        
        if self.type.ledArrayCount != 1 {
            return false
        }
        guard self.peripheral.state == .connected else {
            return false
        }
        
        guard self.useSetall else {
            guard let command = type.ledArrayCommand(statusString) else {
                return false
            }
            self.sendData(data: command)
            Thread.sleep(forTimeInterval: 0.1)
            return true
        }
        
        self.writtenCondition.lock()
        
        self.conditionHelper(condition: self.writtenCondition, holdLock: false,
                             predicate: {
                                self.nextOutputState.ledArray == self.currentOutputState.ledArray
        }, work: {
            self.nextOutputState.ledArray = statusString
        })
        
        self.writtenCondition.unlock()
        return true
        
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
    
    /**
     * Sends the current output state all at once
     *  (rather than sending each change individually)
     * This function is scheduled on a timer. It is called every syncInterval seconds.
     */
    func syncronizeOutputs() {
        self.writtenCondition.lock()
        
        let nextCopy = self.nextOutputState
        
        let changeOccurred = !(nextCopy == self.currentOutputState)
        let currentCPUTime = DispatchTime.now().uptimeNanoseconds
        let timeout = ((currentCPUTime - self.lastWriteStart.uptimeNanoseconds) >
            self.cacheTimeoutDuration)
        let shouldSync = changeOccurred || timeout
        
        NSLog("Sync outputs. \(timeout) \(changeOccurred) \(self.lastWriteWritten)")
        
        if self.initialized && (self.lastWriteWritten || timeout)  && shouldSync {
            
            let command = nextCopy.setAllCommand()
            //TODO: Fix. what if the state has changed in the meantime??
            // maybe I should be checking to see if this needs to be done first.
            // What if the same message is sent twice in a row?
            if nextCopy.buzzer == self.nextOutputState.buzzer {
                self.nextOutputState.buzzer = BBTBuzzer()
            } else {
                print("the buzzer has already changed")
            }
            
            let oldCommand = currentOutputState.setAllCommand()
            if command != oldCommand {
                NSLog("Sending set all.")
                self.sendData(data: command)
            }
            
            //if nextCopy.ledArray != currentOutputState.ledArray, let ledArray = nextCopy.ledArray, let ledArrayCommand = type.ledArrayCommand(ledArray), let clearCommand = type.clearLedArrayCommand() {
                //TODO: maybe only send stop command if changing from flash to symbol
                //self.sendData(data: clearCommand)
            if nextCopy.ledArray != currentOutputState.ledArray, let ledArray = nextCopy.ledArray, let ledArrayCommand = type.ledArrayCommand(ledArray) {
                DispatchQueue.main.asyncAfter(deadline: .now() + self.syncInterval/2) {
                    NSLog("Sending led array change.")
                    self.sendData(data: ledArrayCommand)
                }
            }
            
            self.lastWriteStart = DispatchTime.now()
            self.lastWriteWritten = false
            
            self.currentOutputState = nextCopy
            
            //TODO: if we stop using write requests (sending data .withResponse)
            // then we should remove the lastWriteWritten variable
            self.lastWriteWritten = true
            
            //For debugging
            #if DEBUG
                //let bytes = UnsafeMutableBufferPointer<UInt8>(
                //    start: UnsafeMutablePointer<UInt8>.allocate(capacity: 20), count: 19)
                //let _ = command.copyBytes(to: bytes)
                //print("\(self.creationTime)")
                //print("Setting All: \(bytes.map({return $0}))")
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
        //Sending an ASCII capital X should do the same thing.
        //Useful for legacy firmware
        //TODO: Use the command to turn things off?
        self.writtenCondition.lock()
        self.nextOutputState = BBTRobotOutputState(robotType: type)
        self.writtenCondition.unlock()
        
        return true
    }
    
}
