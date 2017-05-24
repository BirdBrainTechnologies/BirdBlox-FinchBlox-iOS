//
//  FlutterRequests.swift
//  BirdBlox
//
//  Created by birdbrain on 4/19/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import CoreBluetooth
import Swifter

class FlutterRequests: NSObject {
    fileprivate var connected_devices: [String: FlutterPeripheral]
    fileprivate let BLE_Manager: BLECentralManager
    
    var timerDelaySend: Timer?
    var allowSend = true
    let sendInterval = 0.06
    let readInterval = 0.2
    let sendQueue = OperationQueue()
    
    override init(){
        connected_devices = [String: FlutterPeripheral]()
        BLE_Manager = BLECentralManager.getBLEManager()
        sendQueue.maxConcurrentOperationCount = 1
        
    }
    func loadRequests(server: inout HttpServer){
        server["/flutter/discover"] = self.discoverRequest
        server["/flutter/totalStatus"] = self.totalStatusRequest
        
        server["/flutter/:name/connect"] = self.connectRequest
        server["/flutter/:name/disconnect"] = self.disconnectRequest
        
        server["/flutter/:name/out/triled/:port/:red/:green/:blue"] = self.setTriLedRequest
        server["/flutter/:name/out/servo/:port/:angle"] = self.setServoRequest
		server["/flutter/:name/out/buzzer/:vol/:freq"] = self.setBuzzerRequest
        server["/flutter/:name/in/:sensor/:port"] = self.getInput

        
        //TODO: This is hacky. For some reason, discover and totalStatus don't
        // want to be pattern matched to properly
        let old_handler = server.notFoundHandler
        server.notFoundHandler = {
            r in
            if r.path == "/flutter/discover" {
                return self.discoverRequest(request: r)
            } else if r.path == "/flutter/totalStatus" {
                return self.totalStatusRequest(request: r)
            }
            if let handler = old_handler{
                return handler(r)
            } else {
                return .notFound
            }
        }
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
            timerDelaySend = Timer.scheduledTimer(timeInterval: sendInterval, target: self, selector: #selector(HummingbirdRequests.timerElapsedSend), userInfo: nil, repeats: false)
        }
    }
    
    func discoverRequest(request: HttpRequest) -> HttpResponse {
        BLE_Manager.startScan(serviceUUIDs: [FlutterPeripheral.DEVICE_UUID])
        let devices = BLE_Manager.getDiscovered().keys
        print("Found Devices: " + devices.joined(separator: ", "))
        return .ok(.text(devices.joined(separator: "\n")))
    }
    
    func forceDiscover(request: HttpRequest) -> HttpResponse {
        BLE_Manager.stopScan()
        BLE_Manager.startScan(serviceUUIDs: [FlutterPeripheral.DEVICE_UUID])
        let devices = BLE_Manager.getDiscovered().keys
        print("Found Devices: " + devices.joined(separator: ", "))
        return .ok(.text(devices.joined(separator: "\n")))
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
//		print("Total Status device connected")
        return .ok(.text("1"))
		
    }
    
    func connectRequest(request: HttpRequest) -> HttpResponse {
        let name: String = request.params[":name"]!.removingPercentEncoding!
        if (!BLE_Manager.getDiscovered().keys.contains(name)) {
            return .ok(.text("Device not found!"))
        }
        let periph: CBPeripheral = BLE_Manager.getDiscovered()[name]!
        connected_devices[name] = BLE_Manager.connectToFlutter(peripheral: periph)
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
	
	func setBuzzerRequest(request: HttpRequest) -> HttpResponse {
		print("Set buzzer request from \(request.address)")
		
		let name: String = request.params[":name"]!.removingPercentEncoding!
		let volume: UInt8 = UInt8(request.params[":vol"]!)!
		let frequency: UInt16 = UInt16(request.params[":freq"]!)!
		
		print("Setting buzzer to \(name), \(volume), \(frequency)")
		
		if let device = connected_devices[name] {
			if device.setBuzzer(volume: volume, frequency: frequency) {
				return .ok(.text("buzzer Set"))
			}
		}
		return .ok(.text("buzzer not set"))
	}
	
    func getInput(request: HttpRequest) -> HttpResponse {
        let name: String = request.params[":name"]!.removingPercentEncoding!
        let sensor = request.params[":sensor"]!
        let port: Int = Int(request.params[":port"]!)!
        if let device = connected_devices[name] {
            return .ok(.text(String(device.getSensor(port: port, input_type: sensor))))
        }
        return .ok(.text("error"))
    }
}
