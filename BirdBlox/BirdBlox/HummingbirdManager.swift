//
//  HummingbirdRequests.swift
//  BirdBlox
//
//  Created by birdbrain on 3/23/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import CoreBluetooth
import Swifter

class HummingbirdManager {
    fileprivate var connected_devices: [String: HummingbirdPeripheral]
    fileprivate let BLE_Manager: BLECentralManager
    
    var timerDelaySend: Timer?
    var allowSend = true
    let sendInterval = 0.06
    let readInterval = 0.2
    let sendQueue = OperationQueue()
    
	init(){
        connected_devices = [String: HummingbirdPeripheral]()
        BLE_Manager = BLECentralManager.manager
        sendQueue.maxConcurrentOperationCount = 1

    }
    
    func loadRequests(server: BBTBackendServer){
        server["/hummingbird/discover"] = self.discoverRequest
        server["/hummingbird/totalStatus"] = self.totalStatusRequest
		server["/hummingbird/stopDiscover"] = self.stopDiscover
        
        server["/hummingbird/:name/connect"] = self.connectRequest
        server["/hummingbird/:name/disconnect"] = self.disconnectRequest
        
        server["/hummingbird/:name/out/led/:port/:intensity"] = self.setLEDRequest
        server["/hummingbird/:name/out/triled/:port/:red/:green/:blue"] = self.setTriLedRequest
        server["/hummingbird/:name/out/vibration/:port/:intensity"] = self.setVibrationRequest
        server["/hummingbird/:name/out/servo/:port/:angle"] = self.setServoRequest
        server["/hummingbird/:name/out/motor/:port/:speed"] = self.setMotorRequest

        server["/hummingbird/:name/in/:sensor/:port"] = self.getInput
    }
    
    //functions for timer
    @objc func timerElapsedSend(){
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
            timerDelaySend = Timer.scheduledTimer(timeInterval: sendInterval, target: self,
              selector: #selector(HummingbirdManager.timerElapsedSend),
			  userInfo: nil, repeats: false)
        }
    }
    
    func discoverRequest(request: HttpRequest) -> HttpResponse {
        BLE_Manager.startScan(serviceUUIDs: [HummingbirdPeripheral.DEVICE_UUID])
		
		let array = BLE_Manager.discoveredDevices.map { (key, peripheral) in
			["id": key, "name": BLE_Manager.getDeviceNameForGAPName(peripheral.name!)]
		}
		
		print("Found Devices: " + array.map({(d) in d["name"]!}).joined(separator: ", "))
		
		return .ok(.json(array as AnyObject))
    }
    
    func forceDiscover(request: HttpRequest) -> HttpResponse {
        BLE_Manager.stopScan()
        BLE_Manager.startScan(serviceUUIDs: [HummingbirdPeripheral.DEVICE_UUID])
        let devices = BLE_Manager.foundDevices.keys
        print("Found Devices: " + devices.joined(separator: ", "))
        return .ok(.text(devices.joined(separator: "\n")))
    }
	
	func stopDiscover(request: HttpRequest) -> HttpResponse {
		BLE_Manager.stopScan()
		return .ok(.text("Stopped scanning"))
	}
    
    func totalStatusRequest(request: HttpRequest) -> HttpResponse {
        if (connected_devices.isEmpty) {
            return .ok(.text("2"))
        }
        for periph in connected_devices.values {
            if (!periph.isConnected()) {
                return .ok(.text("0"))
            }
        }
        return .ok(.text("1"))
    }
    
    func connectRequest(request: HttpRequest) -> HttpResponse {
        let name: String = request.params[":name"]!.removingPercentEncoding!
        if (!BLE_Manager.foundDevices.keys.contains(name)) {
            return .ok(.text("Device not found!"))
        }
        let periph: CBPeripheral = BLE_Manager.foundDevices[name]!
        connected_devices[name] = BLE_Manager.connectToHummingbird(peripheral: periph)
        return .ok(.text("Connected!"))
    }
    
    func disconnectRequest(request: HttpRequest) -> HttpResponse {
        let name: String = request.params[":name"]!.removingPercentEncoding!
        if (!connected_devices.keys.contains(name)) {
            return .ok(.text("Device not found!"))
        }
        connected_devices[name]?.disconnect()
        connected_devices.removeValue(forKey: name)
        return .ok(.text("Disconnected!"))
    }
    
    func setLEDRequest(request: HttpRequest) -> HttpResponse {
        let name: String = request.params[":name"]!.removingPercentEncoding!
        let port: Int = Int(request.params[":port"]!)!
        let intensity: UInt8 = UInt8(request.params[":intensity"]!)!
        if let device = connected_devices[name] {
            if device.setLED(port: port, intensity: intensity){
                return .ok(.text("LED Set"))
            }
        }
        return .ok(.text("LED not set"))
    }
    
    func setTriLedRequest(request: HttpRequest) -> HttpResponse {
        let name: String = request.params[":name"]!.removingPercentEncoding!
        let port: Int = Int(request.params[":port"]!)!
        let red: UInt8 = UInt8(request.params[":red"]!)!
        let green: UInt8 = UInt8(request.params[":green"]!)!
        let blue: UInt8 = UInt8(request.params[":blue"]!)!
        if let device = connected_devices[name] {
            if device.setTriLed(port: port, r: red, g: green, b: blue) {
                return .ok(.text("Tri-LED set"))
            }
        }
        return .ok(.text("Tri-LED set not set"))
    }
    
    func setServoRequest(request: HttpRequest) -> HttpResponse {
        let name: String = request.params[":name"]!.removingPercentEncoding!
        let port: Int = Int(request.params[":port"]!)!
        let angle: UInt8 = UInt8(request.params[":angle"]!)!
        if let device = connected_devices[name] {
            if device.setServo(port: port, angle: angle){
                return .ok(.text("servo Set"))
            }
        }
        return .ok(.text("servo not set"))
    }
    
    func setVibrationRequest(request: HttpRequest) -> HttpResponse {
        let name: String = request.params[":name"]!.removingPercentEncoding!
        let port: Int = Int(request.params[":port"]!)!
        let intensity: UInt8 = UInt8(request.params[":intensity"]!)!
        if let device = connected_devices[name] {
            if device.setVibration(port: port, intensity: intensity){
                return .ok(.text("Vibration motor Set"))
            }
        }
        return .ok(.text("Vibration motor not set"))
    }
    
    func setMotorRequest(request: HttpRequest) -> HttpResponse {
        let name: String = request.params[":name"]!.removingPercentEncoding!
        let port: Int = Int(request.params[":port"]!)!
        let speed: Int = Int(request.params[":speed"]!)!
        if let device = connected_devices[name] {
            if device.setMotor(port: port, speed: speed){
                return .ok(.text("Motor Set"))
            }
        }
        return .ok(.text("Motor not set"))
    }

    func getInput(request: HttpRequest) -> HttpResponse {
        let name: String = request.params[":name"]!.removingPercentEncoding!
        let sensor = request.params[":sensor"]!
        let port: Int = Int(request.params[":port"]!)!
        if let device = connected_devices[name] {
            print("got device")
            if let data = device.getData() {
                print("got data")
                switch sensor {
                case "distance":
                    return .ok(.text(String(rawToDistance(data[port - 1]))))
                case "temperature":
                    return .ok(.text(String(rawToTemp(data[port - 1]))))
                default:
                    return .ok(.text(String(rawToPercent(data[port - 1]))))
                }
            }
        }
        return .ok(.text("error"))
    }
}
