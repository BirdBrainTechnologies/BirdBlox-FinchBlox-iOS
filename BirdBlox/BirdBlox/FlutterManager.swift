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

class FlutterManager: NSObject {
    fileprivate let BLE_Manager: BLECentralManager
    
    var timerDelaySend: Timer?
    var allowSend = true
    let sendInterval = 0.06
    let readInterval = 0.2
    let sendQueue = OperationQueue()
	var knownPeripherals: [String: CBPeripheral]
    
    override init(){
        BLE_Manager = BLECentralManager.manager
		sendQueue.maxConcurrentOperationCount = 1
		self.knownPeripherals = Dictionary()
    }
	
    func loadRequests(server: BBTBackendServer){
        server["/flutter/discover"] = self.discoverRequest
        server["/flutter/totalStatus"] = self.totalStatusRequest
		server["/flutter/stopDiscover"] = self.stopDiscover
        
        server["/flutter/connect"] = self.connectRequest
        server["/flutter/disconnect"] = self.disconnectRequest
        
        server["/flutter/out/triled"] = self.setTriLedRequest
        server["/flutter/out/servo"] = self.setServoRequest
		server["/flutter/out/buzzer"] = self.setBuzzerRequest
        server["/flutter/in"] = self.getInput
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
        if timerDelaySend == nil {
            timerDelaySend = Timer.scheduledTimer(timeInterval: sendInterval, target: self,
				selector: #selector(HummingbirdManager.timerElapsedSend),
				userInfo: nil, repeats: false)
        }
    }
    
    func discoverRequest(request: HttpRequest) -> HttpResponse {
        BLE_Manager.startScan(serviceUUIDs: [FlutterPeripheral.deviceUUID])
		
		let array = BLE_Manager.discoveredDevices.map { (key, peripheral) in
			["id": key, "name": BBTgetDeviceNameForGAPName(peripheral.name!)]
		}
		
		print("Found Devices: " + array.map({(d) in d["name"]!}).joined(separator: ", "))
		
		return .ok(.json(array as AnyObject))
    }
    
    func forceDiscover(request: HttpRequest) -> HttpResponse {
        BLE_Manager.stopScan()
        BLE_Manager.startScan(serviceUUIDs: [FlutterPeripheral.deviceUUID])
        let devices = BLE_Manager.discoveredDevices.keys
		
		print("Found Devices: " + devices.joined(separator: ", "))
		
        return .ok(.text(devices.joined(separator: "\n")))
    }
	
	func stopDiscover(request: HttpRequest) -> HttpResponse {
		BLE_Manager.stopScan()
		return .ok(.text("Stopped scanning"))
	}
    
    func totalStatusRequest(request: HttpRequest) -> HttpResponse {
        if (BLE_Manager.connectedFlutters.isEmpty) {
            return .ok(.text("2"))
        }
        for periph in BLE_Manager.connectedFlutters.values {
            if (!periph.connected) {
                return .ok(.text("0"))
            }
        }
//		print("Total Status device connected")
        return .ok(.text("1"))
		
    }
    
    func connectRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		if let name = queries["id"] {
			if let periph = BLE_Manager.foundDevices[name] {
				let _ = BLE_Manager.connectToFlutter(peripheral: periph)
				self.knownPeripherals[name] = periph
				return .ok(.text("Connected!"))
			}
			else {
				return .internalServerError
			}
		}
		
		return .badRequest(.text("Malformed Request"))
    }
	
    func disconnectRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		guard let name = queries["id"] else {
			return .badRequest(.text("Malformed Request"))
		}
		
		if BLE_Manager.connectedFlutters.keys.contains(name) {
			BLE_Manager.connectedFlutters[name]!.disconnect()
			return .ok(.text("Disconnected!"))
		} else if let peripheral = self.knownPeripherals[name] {
			BLE_Manager.disconnect(peripheral: peripheral)
			return .ok(.text("Disconnected!"))
		} else {
			return .notFound
		}
    }
	
    func setTriLedRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		if let name = queries["id"],
			let portStr = queries["port"],
			let redStr = queries["red"],
			let greenStr = queries["green"],
			let blueStr = queries["blue"],
			let port = UInt(portStr),
			let red = UInt8(redStr),
			let green = UInt8(greenStr),
			let blue = UInt8(blueStr) {
	
			if let device = BLE_Manager.connectedFlutters[name] {
				if device.setTriLED(port: port, intensities: BBTTriLED(red, green, blue)) {
					return .ok(.text("Tri-LED set"))
				} else {
					return .internalServerError
				}
			} else {
				return .notFound
			}
        }
		
		return .badRequest(.text("Malformed Request"))
    }
    
    func setServoRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		if let name = queries["id"],
			let portStr = queries["port"],
			let angleStr = queries["angle"],
			let port = UInt(portStr),
			let angle = UInt8(angleStr) {
			
			if let device = BLE_Manager.connectedFlutters[name] {
				if device.setServo(port: port, angle: angle){
					return .ok(.text("servo Set"))
				} else {
					return .internalServerError
				}
			} else {
				return .notFound
			}
        }
		
		return .badRequest(.text("Malformed Request"))
    }
	
	func setBuzzerRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		if let name = queries["id"],
			let volumeStr = queries["volume"],
			let frequencyStr = queries["frequency"],
			let volume = Int(volumeStr),
			let frequency = Int(frequencyStr) {
		
			if let device = BLE_Manager.connectedFlutters[name] {
				if device.setBuzzer(volume: volume, frequency: frequency) {
					return .ok(.text("buzzer Set"))
				} else {
					return .internalServerError
				}
			} else {
				return .notFound
			}
		}
		
		return .badRequest(.text("Malformed Request"))
	}
	
    func getInput(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		if let name = queries["id"],
			let portStr = queries["port"],
			let sensor = queries["sensor"],
			let port = Int(portStr) {
			
			if let device = BLE_Manager.connectedFlutters[name] {
				if let sensorValue = device.getSensor(port: port, input_type: sensor) {
					return .ok(.text(String(sensorValue)))
				} else {
					return .internalServerError
				}
			}
			else {
				return .notFound
			}
		}
		
		return .badRequest(.text("Malformed Request"))
    }
}
