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
    public let name: String
    private let connectionAttempts: Int //How many times have we already tried to connect to this peripheral?
    private let BLE_Manager: BLECentralManager
	
    public var id: String {
        return self.peripheral.identifier.uuidString
    }
    public var connected: Bool {
        return peripheral.state == CBPeripheralState.connected
    }
    
    var rx_line, tx_line: CBCharacteristic?
    
    private var lastSensorUpdate: [UInt8]
    var sensorValues: [UInt8] { return lastSensorUpdate }
    var compassCalibrated: Bool = false
    var batteryStatus: BatteryStatus?
    
    private let initializationCompletion: ((BBTRobotBLEPeripheral) -> Void)?
    private var _initialized = false
    public var initialized: Bool {
        return self._initialized
    }
    
    //MARK: Variables to coordinate set all
    private var writtenCondition: NSCondition = NSCondition()
    private var useWithResponse = false //For most devices, we send commands .withoutResponse
    
    //MARK: Variables write protected by writtenCondition
    private var currentOutputState: BBTRobotOutputState
    public var nextOutputState: BBTRobotOutputState
    var lastWriteWritten: Bool = true
    var lastWriteStart: DispatchTime = DispatchTime.now()
    //End variables write protected by writtenCondition
    
    private var syncTimer: Timer = Timer()
    let syncInterval = 0.03125 //(32Hz)
    let cacheTimeoutDuration: UInt64 = 1 * 1_000_000_000 //nanoseconds
    let waitRefreshTime = 0.5 //seconds
    
    let creationTime = DispatchTime.now()
    
    var commandPending: Data? = nil //TODO: Delete? For use with led arrays and .withResponse
    
    private var initializingCondition = NSCondition()
    private var lineIn: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0]
    private var hardwareString = ""
    private var firmwareVersionString = ""
    private var oldFirmware = false
    
    override public var description: String {
        let gapName = self.peripheral.name ?? "Unknown"
        
        var updateDesc = ""
        if self.oldFirmware {
            updateDesc = "\n\nThis \(type.description) needs to be updated. " +
                "See the link below: \n" +
            "http://www.hummingbirdkit.com/learning/installing-birdblox#BurnFirmware "
        }
        
        return
            "\(self.type.description) Peripheral\n" +
                "Name: \(self.name)\n" +
                "Bluetooth Name: \(gapName)\n" +
                "Hardware Version: \(self.hardwareString)\n" +
                "Firmware Version: \(self.firmwareVersionString)" + updateDesc
    }
    
    
    //MARK: INIT
    
    required init(_ peripheral: CBPeripheral, _ type: BBTRobotType, _ attempt: Int, _ completion: ((BBTRobotBLEPeripheral) -> Void)? = nil){
        self.peripheral = peripheral
        self.type = type
        self.connectionAttempts = attempt
        self.name = BBTgetDeviceNameForGAPName(self.peripheral.name ?? "Unknown")
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
                    switch type{
                    case .Hummingbird, .HummingbirdBit, .MicroBit:
                        DispatchQueue.main.async {
                            self.initializeDevice()
                        }
                        return
                    case .Finch, .Flutter:
                        NSLog("Finch and Flutter not currently supported.")
                        return
                    }
                }
            }
        }
    }
    private func initializeDevice() {
        NSLog("Beginning initialization of \(self.name) (\(self.type.description)).")
        
        if type == .Hummingbird, let name = peripheral.name, name.starts(with: "HB") {
            print("\(self.name) will use .withResponse.")
            self.useWithResponse = true
        }
        
        //Get ourselves a fresh slate
        print("About to send poll stop")
        self.sendData(data: type.sensorCommand("pollStop"))
        //peripheral.writeValue(type.sensorCommand("pollStop"), for: tx_line!, type: .withResponse)
        print("just sent poll stop")
        
        //Check firmware version.
        let timeoutTime = Date(timeIntervalSinceNow: TimeInterval(7)) //seconds
        self.initializingCondition.lock()
        let oldLineIn = self.lineIn
        
        guard let versioningCommand = type.hardwareFirmwareVersionCommand() else {
            BLE_Manager.disconnect(byID: self.id)
            NSLog("Initialization failed. Device type \(type.description) not supported.")
            return
        }
        print("about to send versioning command")
        //peripheral.writeValue(versioningCommand, for: tx_line!, type: .withResponse)
        self.sendData(data: versioningCommand)
        print("sent versioning command")
        
        //Wait until we get a response or until we timeout.
        while (self.lineIn == oldLineIn) {
            if (Date().timeIntervalSince(timeoutTime) >= 0) {
                
                NSLog("\(self.name) initialization failed due to timeout. Connected? \(self.connected)")
                //BLE_Manager.disconnect(byID: self.id)
                
                if self.connectionAttempts < 10 {
                    BLE_Manager.connectToRobot(byPeripheral: self.peripheral, ofType: self.type)
                    NSLog("\(self.name) Reconnecting...")
                } else {
                    NSLog ("Not attempting to reconnect \(self.name). There have been \(self.connectionAttempts) attempts already. Currently connected? \(self.connected)")
                    BLE_Manager.disconnect(byID: self.id)
                    let _ = FrontendCallbackCenter.shared.robotDisconnected(name: self.name, reason: "initialization timeout") //TODO: Remove from frontend list somehow
                }
                return
            }
            self.initializingCondition.wait(until: Date(timeIntervalSinceNow: 1))
        }
        let versionArray = self.lineIn
        
        //set the hardware and firmware version values
        switch type {
        case .Hummingbird:
            self.hardwareString = String(versionArray[0]) + "." + String(versionArray[1])
            self.firmwareVersionString = String(versionArray[2]) + "." + String(versionArray[3]) +
                (String(bytes: [versionArray[4]], encoding: .ascii) ?? "")
        case .HummingbirdBit:
            self.hardwareString = String(versionArray[0])
            self.firmwareVersionString = "\(versionArray[1])/\(versionArray[2])"
        case .MicroBit:
            self.hardwareString = String(versionArray[0])
            self.firmwareVersionString = String(versionArray[1])
        case .Flutter, .Finch:
            NSLog("Firmware and Hardware version not set for types not supported.")
        }
        
        
        print("Version array: \(versionArray)")

        self.initializingCondition.unlock()
        
        //TODO: is this the best place to check this? Also checking above...
        guard self.connected else {
            let _ = FrontendCallbackCenter.shared.robotDisconnected(name: self.name, reason: "lost connection")
            
            BLE_Manager.disconnect(byID: self.id)
            NSLog("Initialization failed because device got disconnected.")
            return
        }
        
        //Check firmware version to make sure it is above the min
        switch type {
        case .Hummingbird:
            //TODO: Handle different min firmwares for different robot types
            //TODO: I don't think this is working properly. On a bluefruit adapter (HB88756) I got the version
            // array: [143, 153, 148, 135, 132, 0, 0, 0] and sometimes didn't get anything and the
            // whole program crashed. Sometimes the version numbers are at the end, but not always
            //If the firmware version is too low, then disconnect and inform the user.
            //Must be higher than 2.2b OR be 2.1i
            //guard versionArray[2] >= 2 &&
            //    ((versionArray[3] >= 2) || (versionArray[3] == 1 && versionArray[4] >= 105)) else {
            guard versionArray[2] >= 2 && versionArray[3] >= 2 else {
                    let _ = FrontendCallbackCenter.shared
                        .robotFirmwareIncompatible(robotType: type, id: self.id, firmware: self.firmwareVersionString)
                    
                    BLE_Manager.disconnect(byID: self.id)
                    NSLog("Initialization failed due to incompatible firmware.")
                    return
            }
            
            //Old firmware, but still compatible
            if versionArray[3] == 1 && versionArray[4] >= 105 {
                let _ = FrontendCallbackCenter.shared.robotFirmwareStatus(id: self.id, status: "old")
                self.oldFirmware = true
            }
            
        case .HummingbirdBit, .MicroBit:
            
            //versionArray[1] is micro:bit firmware, versionArray[2] is SAMD (on bit board)
            //As of now, there is no firmware for these that is not compatible.
            if versionArray[1] < 1 || versionArray[2] < 1 {
                let _ = FrontendCallbackCenter.shared.robotFirmwareStatus(id: self.id, status: "old")
                self.oldFirmware = true
            }
            
        case .Finch, .Flutter:
            //TODO: (finch) add a check for legacy firmware and use set all for only
            //firmwares newer than 2.2.a
            //From Tom: send the characters 'G' '4' and you will get back the hardware version
            //(currently 0x03 0x00) and the firmware version (0x02 0x02 'b'), might be 'a' instead of 'b'
            BLE_Manager.disconnect(byID: self.id)
            NSLog("Initialization failed because Finch and Flutter not currently supported!")
            return
        }
        
        //TODO: do we really need this?
        Thread.sleep(forTimeInterval: 0.1)
        
        //Start polling for sensor data
        print("Sending poll start")
        self.sendData(data: type.sensorCommand("pollStart"))
        
        //Start sending periodic updates. All changes to outputs will be set at this time.
        //TODO: scheduledTimer isn't very reliable. Switch to scheduleRepeating when stop supporting iOS9
        self.syncTimer = Timer.scheduledTimer(timeInterval: self.syncInterval, target: self,
                                 selector: #selector(syncronizeOutputs), userInfo: nil, repeats: true)
        self.syncTimer.fire()
        
        self._initialized = true
        print("\(self.type.description) \(self.name) initialized")
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
            NSLog("Error in didUpdateValueFor: \(error.debugDescription)")
            return
        }
        
        if characteristic.uuid != type.RX_UUID {
            NSLog("Wrong characteristic uuid \(characteristic.uuid)")
            return
        }
        
        guard let inData = characteristic.value else {
            NSLog("No characteristic value set for \(characteristic)")
            return
        }
        
        //let temp = [UInt8](inData)
        //print("Characteristic updated to \(temp)")
        
        //This block used for getting the firmware info
        guard self.initialized else {
            self.initializingCondition.lock()
            print("Got version data in: \(inData.debugDescription)")
            if self.type == .Hummingbird && inData.count > 5 {
                //In this case, the version information is appended to the end of a sensor poll update
                inData.suffix(5).copyBytes(to: &self.lineIn, count: self.lineIn.count)
            } else {
                inData.copyBytes(to: &self.lineIn, count: self.lineIn.count)
            }
            print("Copied to lineIn: \(self.lineIn)")
            self.initializingCondition.signal()
            self.initializingCondition.unlock()
            return
        }
        
        //TODO: Why is this? Hummingbird duo seems to send a lot
        //of different length messages. Are they for different things?
        if type == .Hummingbird && characteristic.value!.count % 5 != 0 {
            print("Characteristic value \(characteristic.value!.count) not divisible by 5.")
            return
        }
        
        //Assume it's sensor in data
        inData.copyBytes(to: &self.lastSensorUpdate, count: type.sensorByteCount)
        
        //Check the state of compass calibration
        if type == .HummingbirdBit || type == .MicroBit {
            let byte = self.lastSensorUpdate[7]
            let bits = byteToBits(byte)
            
            if bits[3] == 1 {
                //print("CALIBRATION FAILED \(bits)")
                self.compassCalibrated = false
            } else if bits[2] == 1 {
                //print("CALIBRATION SUCCESSFUL \(bits)")
                self.compassCalibrated = true
            } else {
                //print("CALIBRATION UNKNOWN \(bits)")
                self.compassCalibrated = false
            }
        }
        
        //Check battery status. Stored in sensor 4 for bit and sensor 5 for duo
        if let i = type.batteryVoltageIndex, let greenThreshold = type.batteryGreenThreshold, let yellowThreshold = type.batteryYellowThreshold {
            let voltage = rawToVoltage( lastSensorUpdate[i] )
            
            let newStatus: BatteryStatus
            if voltage > greenThreshold {
                newStatus = BatteryStatus.green
            } else if voltage > yellowThreshold {
                newStatus = BatteryStatus.yellow
            } else {
                newStatus = BatteryStatus.red
            }
            
            if self.batteryStatus != newStatus {
                self.batteryStatus = newStatus
                let _ = FrontendCallbackCenter.shared.robotUpdateBattery(id: self.peripheral.identifier.uuidString, batteryStatus: newStatus.rawValue)
            }
            
            //print("Voltage!! \(voltage) \(lastSensorUpdate[i]) \(self.batteryStatus)")
        }
    }
    
    /**
     * Called when we get a response bact after updating
     * a characteristic (when we write to the HB or finch).
     * Not called after a write that is .withoutResponse
     */
    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            NSLog("Unable to write to \(type.description) due to error \(error)")
        }
        
        NSLog("Did write value.")
        
        //We successfully sent a command
        self.writtenCondition.lock()
        
        if let pendingCommand = self.commandPending {//TODO: remove this? not needed for duo
            NSLog("Sending an led array command now that response has been received.")
            sendData(data: pendingCommand)
            self.commandPending = nil
            self.lastWriteStart = DispatchTime.now()
        } else {
            self.lastWriteWritten = true
            self.writtenCondition.signal()
        }
        
        self.writtenCondition.unlock()
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
    
    /**
     * Main function used to send data to the robot.
     * Called from syncronizeOutputs, and also during initialization
     */
    private func sendData(data: Data) {
        if self.connected {
            
            if self.useWithResponse {
                peripheral.writeValue(data, for: tx_line!, type: .withResponse) //set lastWriteWritten to true when response received
            } else {
                peripheral.writeValue(data, for: tx_line!, type: .withoutResponse)
            }
            
        } else {
            //TODO: something else here?
            NSLog("Trying to send \(data) to \(self.name) but self.connected is \(self.connected).")
        }
    }
    
 
    private func conditionHelper(condition: NSCondition, holdLock: Bool = true,
                                 predicate: (() -> Bool), work: (() -> ())) {
        if holdLock {
            condition.lock()
        }
        
        while !predicate() {
            NSLog("waiting...")
            condition.wait(until: Date(timeIntervalSinceNow: self.waitRefreshTime))
        }
        
        work()
        
        condition.signal()
        if holdLock {
            condition.unlock()
        }
    }
    /**
     * Set a specific output to be set next time setAll is sent.
     * Returns false if this output cannot be set
     */
    private func setOutput(ifCheck isValid: Bool, when predicate: (() -> Bool), set work: (() -> ())) -> Bool {
        
        guard self.peripheral.state == .connected else {
            return false
        }
        if !isValid {
            return false
        }
        
        self.conditionHelper(condition: self.writtenCondition, predicate: predicate, work: work)
        
        return true
    }
    
    //MARK: Robot outputs
    func setLED(port: Int, intensity: UInt8) -> Bool {
        
        let i = Int(port - 1)
        
        return setOutput(ifCheck: (self.type.ledCount >= port),
                         when: {self.nextOutputState.leds![i] == self.currentOutputState.leds![i] },
                         set: { self.nextOutputState.leds![i] = intensity })
    }
    
    func setTriLED(port: UInt, intensities: BBTTriLED) -> Bool {
        
        let i = Int(port - 1)
        
        return setOutput(ifCheck: (self.type.triledCount >= port),
                         when: {self.nextOutputState.trileds![i] == self.currentOutputState.trileds![i]},
                         set: {self.nextOutputState.trileds![i] = intensities})
    }
    
    func setVibration(port: Int, intensity: UInt8) -> Bool {
        
        let i = Int(port - 1)
        
        return setOutput(ifCheck: (self.type.vibratorCount >= port),
                         when: {self.nextOutputState.vibrators![i] == self.currentOutputState.vibrators![i]},
                         set: {self.nextOutputState.vibrators![i] = intensity})
    }
    
    func setMotor(port: Int, speed: Int8) -> Bool {
        
        let i = Int(port - 1)
        
        return setOutput(ifCheck: (self.type.motorCount >= port),
                         when: {self.nextOutputState.motors![i] == self.currentOutputState.motors![i]},
                         set: {self.nextOutputState.motors![i] = speed})
    }
    
    func setServo(port: UInt, value: UInt8) -> Bool {
        
        let i = Int(port - 1)
        
        return setOutput(ifCheck: (self.type.servoCount >= port),
                         when: {self.nextOutputState.servos![i] == self.currentOutputState.servos![i]},
                         set: {self.nextOutputState.servos![i] = value})
    }
    
    func setBuzzer(period: UInt16, duration: UInt16) -> Bool {
        
        return setOutput(ifCheck: (self.type.buzzerCount == 1),
                         when: {self.nextOutputState.buzzer! == self.currentOutputState.buzzer!},
                         set: {self.nextOutputState.buzzer = BBTBuzzer(period: period, duration: duration)})
    }
    
    func setLedArray(_ statusString: String) -> Bool {
        
        return setOutput(ifCheck: (self.type.ledArrayCount == 1),
                         when: {self.nextOutputState.ledArray == self.currentOutputState.ledArray},
                         set: {self.nextOutputState.ledArray = statusString})
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
        
        //NSLog("Sync outputs. \(timeout) \(changeOccurred) \(self.lastWriteWritten)")
        
        if self.initialized && (self.lastWriteWritten || timeout)  && shouldSync {
            
            //if timeout { NSLog("Timeout") }
            
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
                self.lastWriteStart = DispatchTime.now()
                if self.useWithResponse { self.lastWriteWritten = false }
            }
            
            //if nextCopy.ledArray != currentOutputState.ledArray, let ledArray = nextCopy.ledArray, let ledArrayCommand = type.ledArrayCommand(ledArray), let clearCommand = type.clearLedArrayCommand() {
                //TODO: maybe only send stop command if changing from flash to symbol
                //self.sendData(data: clearCommand)
            if nextCopy.ledArray != currentOutputState.ledArray, let ledArray = nextCopy.ledArray, let ledArrayCommand = type.ledArrayCommand(ledArray) {
                if !self.lastWriteWritten {
                    NSLog("Putting led array command into pending...")
                    self.commandPending = ledArrayCommand
                } else {
                    if self.useWithResponse {self.lastWriteWritten = false}
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.syncInterval/2) {
                        NSLog("Sending led array change.")
                        self.sendData(data: ledArrayCommand)
                        self.lastWriteStart = DispatchTime.now()  //TODO: need this? or lastwritewritten above?
                    }
                }
            }
            
            self.currentOutputState = nextCopy
            
        } else {
            if !self.lastWriteWritten {
                NSLog("Trying to sync outputs before last write has been written.")
            }
        }
        
        if !self.useWithResponse { self.writtenCondition.signal() }
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
    
    func calibrateCompass() -> Bool {
        if let command = self.type.calibrateMagnetometerCommand() {
            sendData(data: command)
            return true
        } else {
            return false
        }
    }
    
}
