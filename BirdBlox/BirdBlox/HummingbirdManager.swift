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
        
        server["/hummingbird/connect"] = self.connectRequest
        server["/hummingbird/disconnect"] = self.disconnectRequest
        
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
        BLE_Manager.startScan(serviceUUIDs: [HummingbirdPeripheral.DEVICE_UUID])
		
		let array = BLE_Manager.discoveredDevices.map { (key, peripheral) in
			["id": key, "name": BBTgetDeviceNameForGAPName(peripheral.name!)]
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
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		if let name = queries["id"]?.removingPercentEncoding {
			if BLE_Manager.foundDevices.keys.contains(name) {
				let periph: CBPeripheral = BLE_Manager.foundDevices[name]!
				connected_devices[name] = BLE_Manager.connectToHummingbird(peripheral: periph)
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
		
		if let name = queries["id"]?.removingPercentEncoding {
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
    
    func setLEDRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		if let name = queries["id"]?.removingPercentEncoding,
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
		
		if let name = queries["id"]?.removingPercentEncoding,
			let portStr = queries["port"],
			let redStr = queries["red"],
			let greenStr = queries["green"],
			let blueStr = queries["blue"],
			let port = Int(portStr),
			let red = UInt8(redStr),
			let green = UInt8(greenStr),
			let blue = UInt8(blueStr) {
			
			if let device = connected_devices[name] {
				if device.setTriLed(port: port, r: red, g: green, b: blue) {
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
		
		if let name = queries["id"]?.removingPercentEncoding,
			let portStr = queries["port"],
			let angleStr = queries["angle"],
			let port = Int(portStr),
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
		
		if let name = queries["id"]?.removingPercentEncoding,
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
		
		if let name = queries["id"]?.removingPercentEncoding,
			let portStr = queries["port"],
			let speedStr = queries["speed"],
			let port = Int(portStr),
			let speed = Int(speedStr) {
			
			if let device = connected_devices[name] {
				if device.setMotor(port: port, speed: speed){
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
		
		if let name = queries["id"]?.removingPercentEncoding,
			let portStr = queries["port"],
			let sensor = queries["sensor"],
			let port = Int(portStr) {
			
			if let device = connected_devices[name] {
				if let data = device.getData()  {
					switch sensor {
					case "distance":
						return .ok(.text(String(rawToDistance(data[port - 1]))))
					case "temperature":
						return .ok(.text(String(rawToTemp(data[port - 1]))))
					default:
						return .ok(.text(String(rawToPercent(data[port - 1]))))
					}
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
