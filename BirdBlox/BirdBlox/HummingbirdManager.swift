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
        BLE_Manager = BLECentralManager.shared
        sendQueue.maxConcurrentOperationCount = 1

    }
    
    func loadRequests(server: BBTBackendServer){
        server["/hummingbird/discover"] = self.discoverRequest
		server["/hummingbird/stopDiscover"] = self.stopDiscover
        
        server["/hummingbird/connect"] = self.connectRequest
        server["/hummingbird/disconnect"] = self.disconnectRequest
		
		server["/hummingbird/out/stopEverything"] = self.stopAllRequest
        server["/hummingbird/out/led"] = self.setLEDRequest
        server["/hummingbird/out/triled"] = self.setTriLedRequest
        server["/hummingbird/out/vibration"] = self.setVibrationRequest
        server["/hummingbird/out/servo"] = self.setServoRequest
        server["/hummingbird/out/motor"] = self.setMotorRequest

        server["/hummingbird/in"] = self.getInput
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
        BLE_Manager.startScan(serviceUUIDs: [HummingbirdPeripheral.deviceUUID])
		
		let altName = "Fetching name..."
		
		let darray = BLE_Manager.foundDevices.map { (key, peripheral) in
			["id": key, "name": BBTgetDeviceNameForGAPName(peripheral.name ?? altName)]
		}
		
		print("Found Devices: " + darray.map({(d) in d["name"]!}).joined(separator: ", "))
		
		return .ok(.json(darray as AnyObject))
    }
    
    func forceDiscover(request: HttpRequest) -> HttpResponse {
        BLE_Manager.stopScan()
        BLE_Manager.startScan(serviceUUIDs: [HummingbirdPeripheral.deviceUUID])
        let devices = BLE_Manager.foundDevices.keys
        print("Found Devices: " + devices.joined(separator: ", "))
        return .ok(.text(devices.joined(separator: "\n")))
    }
	
	func stopDiscover(request: HttpRequest) -> HttpResponse {
		BLE_Manager.stopScan()
		return .ok(.text("Stopped scanning"))
	}
    
    func connectRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		if let name = queries["id"] {
			if BLE_Manager.foundDevices.keys.contains(name) {
				let periph: CBPeripheral = BLE_Manager.foundDevices[name]!
				BLE_Manager.connectToHummingbird(peripheral: periph) {
					self.connected_devices[name] = HummingbirdPeripheral(peripheral: periph)
				}
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
		
		if let name = queries["id"] {
			if connected_devices.keys.contains(name) {
				connected_devices[name]!.disconnect()
				connected_devices.removeValue(forKey: name)
				return .ok(.text("Disconnected!"))
			} else {
				return .notFound
			}
		}
		
		return .badRequest(.text("Malformed Request"))
    }
	
	
	func stopAllRequest(request: HttpRequest) -> HttpResponse {
		for hb in connected_devices.values {
			let _ = hb.setAllOutputsToOff()
		}
		
		return .ok(.text("Issued stop commands to every connected Hummingbird."))
	}
    
    func setLEDRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		if let name = queries["id"],
			let portStr = queries["port"],
			let intensityStr = queries["intensity"],
			let port = Int(portStr),
			let intensity = UInt8(intensityStr) {
		
			if let device = connected_devices[name] {
				if device.setLED(port: port, intensity: intensity){
					return .ok(.text("LED Set"))
				} else {
					return .internalServerError
				}
			} else {
				return .notFound
			}
        }
		
		return .badRequest(.text("Malformed Request"))
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
			
			if let device = connected_devices[name] {
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
			
			if let device = connected_devices[name] {
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
	
    func setVibrationRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		if let name = queries["id"],
			let portStr = queries["port"],
			let intensityStr = queries["intensity"],
			let port = Int(portStr),
			let intensity = UInt8(intensityStr) {
			
			if let device = connected_devices[name] {
				if device.setVibration(port: port, intensity: intensity){
					return .ok(.text("LED Set"))
				} else {
					return .internalServerError
				}
			} else {
				return .notFound
			}
		}
		
		return .badRequest(.text("Malformed Request"))
    }
    
    func setMotorRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		if let name = queries["id"],
			let portStr = queries["port"],
			let speedStr = queries["speed"],
			let port = Int(portStr),
			let speed = Int(speedStr) {
			
			if let device = connected_devices[name] {
				if device.setMotor(port: port, speed: Int8(speed)){
					return .ok(.text("LED Set"))
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
			
			if let device = connected_devices[name] {
				let data = device.sensorValues
				switch sensor {
				case "distance":
					return .ok(.text(String(rawToDistance(data[port - 1]))))
				case "temperature":
					return .ok(.text(String(rawToTemp(data[port - 1]))))
				default:
					return .ok(.text(String(rawToPercent(data[port - 1]))))
				}
			}
			else {
				return .notFound
			}
		}
		
		return .badRequest(.text("Malformed Request"))
	}
}
