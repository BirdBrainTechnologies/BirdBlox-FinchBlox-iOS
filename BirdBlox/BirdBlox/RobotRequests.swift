//
//  RobotRequests.swift
//  BirdBlox
//
//  Created by Jeremy Huang on 2017-07-21.
//  Copyright © 2017年 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import CoreBluetooth
import Swifter

class RobotRequests {
	private let bleCenter = BLECentralManager.shared
	
	static private let robotTypeKey = "type"
	
	static private func handler(fromIDAndTypeHandler:
								@escaping ((String, BBTRobotType, HttpRequest) -> HttpResponse))
	-> ((HttpRequest) -> HttpResponse) {
		
		func handler(request: HttpRequest) -> HttpResponse {
			let queries = BBTSequentialQueryArrayToDict(request.queryParams)
			
			guard let idStr = queries["id"],
				let typeStr = queries[RobotRequests.robotTypeKey] else {
					return .badRequest(.text("Missing parameter"))
			}
			
			guard let type = BBTRobotType.fromString(typeStr) else {
				return .badRequest(.text("Invalid robot type: \(typeStr)"))
			}
			
			return fromIDAndTypeHandler(idStr, type, request)
		}
		
		return handler
	}
	
	public func loadRequests(server: BBTBackendServer) {
		server["/robot/startDiscover"] = self.discoverRequest
		server["/robot/stopDiscover"] = self.stopDiscoverRequest
		
		server["/robot/connect"] = RobotRequests.handler(fromIDAndTypeHandler: self.connectRequest)
		server["/robot/disconnect"] = self.disconnectRequest
		
		server["/robot/stopAll"] = self.stopAllRequest
		server["/robot/out/triled"] =
			RobotRequests.handler(fromIDAndTypeHandler: self.setTriLEDRequest)
		server["/robot/out/servo"] =
			RobotRequests.handler(fromIDAndTypeHandler: self.setServoRequest)
		
		server["/robot/out/stopEverything"] = self.stopAllRequest
		server["/robot/out/led"] = RobotRequests.handler(fromIDAndTypeHandler: self.setLEDRequest)
		server["/robot/out/vibration"] =
			RobotRequests.handler(fromIDAndTypeHandler: self.setVibrationRequest)
		server["/robot/out/motor"] =
			RobotRequests.handler(fromIDAndTypeHandler: self.setMotorRequest)
		
		server["/robot/out/buzzer"] =
			RobotRequests.handler(fromIDAndTypeHandler: self.setBuzzerRequest)
		
		server["/robot/in"] = RobotRequests.handler(fromIDAndTypeHandler: self.inputRequest)
		
		server["/robot/showInfo"] = RobotRequests.handler(fromIDAndTypeHandler: self.infoRequest)
		
		//TODO: Delete
		server["/robot/out/setAll"] = RobotRequests.handler(fromIDAndTypeHandler: self.setAll)
	}
	
	private func discoverRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		guard let typeStr = queries[RobotRequests.robotTypeKey] else {
			return .badRequest(.text("Missing Query Parameter"))
		}
		
		guard let type = BBTRobotType.fromString(typeStr) else {
			return .badRequest(.text("Invalid robot type: \(typeStr)"))
		}
		
		bleCenter.startScan(serviceUUIDs: [type.scanningUUID], updateDiscovered: { (peripherals) in
			let altName = "Fetching name..."
			let darray = peripherals.map { (peripheral) in
				["id": peripheral.identifier.uuidString,
				 "name": BBTgetDeviceNameForGAPName(peripheral.name ?? altName)]
			}
			
			let _ = FrontendCallbackCenter.shared.updateDiscoveredRobotList(typeStr: typeStr,
			                                                                robotList: darray)
		}, scanEnded: {
			let _ = FrontendCallbackCenter.shared.scanHasStopped(typeStr: typeStr)
		})
		
		return .ok(.text("Scanning started"))
	}
	
	private func stopDiscoverRequest(request: HttpRequest) -> HttpResponse {
		bleCenter.stopScan()
		return .ok(.text("Stopped scanning"))
	}
	
	
	private func connectRequest(id: String, type: BBTRobotType,
	                            request: HttpRequest) -> HttpResponse {
		let idExists = bleCenter.connectToRobot(byID: id, ofType: type)
		
		if idExists == false {
			return .notFound
		}
		
		return .ok(.text("Connected!"))
	}
	
	private func disconnectRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		guard let id = queries["id"] else {
			return .badRequest(.text("Missing Parameter"))
		}
		//Disconnect even if the robot is still initializing
//		guard bleCenter.isRobotWithIDConnected(id) else {
//			return .notFound
//		}
		
		bleCenter.disconnect(byID: id)
		return .ok(.text("Disconnected"))
	}
	
	
	private func infoRequest(id: String, type: BBTRobotType,
	                         request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		guard let id = queries["id"] else {
			return .badRequest(.text("Missing Parameter"))
		}
		guard let robot = bleCenter.robotForID(id) else {
			return .notFound
		}
		
		let text = FrontendCallbackCenter.safeString(from: robot.description)
		
		let _ = FrontendCallbackCenter.shared.echo(getRequestString:
			"/tablet/choice?question=\(text)&button1=Dismiss")
		
		
		return .ok(.text("Info shown"))
	}
	
	
	//MARK: Requests for all types
	
	private func stopAllRequest(request: HttpRequest) -> HttpResponse {
		bleCenter.forEachConnectedRobots(do: { robot in
			let _ = robot.setAllOutputsToOff()
		})
		
		return .ok(.text("Issued stop commands to every connected Hummingbird."))
	}
	
	private func getRobotOrResponse(id: String, type: BBTRobotType, acceptTypes: [BBTRobotType])
	 -> (BBTRobotBLEPeripheral?, HttpResponse?) {
		guard let robot = bleCenter.robotForID(id) else {
			return (nil, .notFound)
		}
		
		guard type(of: robot).type == type else {
			return (nil,.badRequest(.text("Type of robot does not match type passed in parameter")))
		}
		
		guard acceptTypes.contains(type(of: robot).type) else {
			return (nil, .badRequest(.text("Operation not supported by type")))
		}
		
		return (robot, nil)
	}
	
	private func setTriLEDRequest(id: String, type: BBTRobotType,
	                              request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		guard let portStr = queries["port"],
			let redStr = queries["red"],
			let greenStr = queries["green"],
			let blueStr = queries["blue"],
			let port = UInt(portStr),
			let red = UInt8(redStr),
			let green = UInt8(greenStr),
			let blue = UInt8(blueStr) else {
				
				return .badRequest(.text("Missing or invalid parameters"))
		}
		
		let (roboto, requesto) = self.getRobotOrResponse(id: id, type: type,
		                                                 acceptTypes: [.Hummingbird, .Flutter])
		guard let robot = roboto else {
			return requesto!
		}
		
		if robot.setTriLED(port: port, intensities: BBTTriLED(red, green, blue)) {
			return .ok(.text("set"))
		} else {
			return .internalServerError
		}
	}
	
	private func setServoRequest(id: String, type: BBTRobotType,
	                             request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		guard let portStr = queries["port"],
			let angleStr = queries["angle"],
			let port = UInt(portStr),
			let angle = UInt8(angleStr) else {
				
				return .badRequest(.text("Missing or invalid parameters"))
		}
		
		let (roboto, requesto) = self.getRobotOrResponse(id: id, type: type,
		                                                 acceptTypes: [.Hummingbird, .Flutter])
		guard let robot = roboto else {
			return requesto!
		}
		
		if robot.setServo(port: port, angle: angle) {
			return .ok(.text("set"))
		} else {
			return .internalServerError
		}
	}
	
	private func inputRequest(id: String, type: BBTRobotType,
	                          request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		guard let portStr = queries["port"],
			let sensor = queries["sensor"],
			var port = Int(portStr) else {
				
				return .badRequest(.text("Malformed Request"))
		}
		
		let (roboto, requesto) = self.getRobotOrResponse(id: id, type: type,
		                                                 acceptTypes: [.Flutter, .Hummingbird])
		guard let robot = roboto else {
			return requesto!
		}
		
		let values = robot.sensorValues
		
		port -= 1
		guard port < values.count && port >= 0 else {
			return .badRequest(.text("Port is out of bounds"))
		}
		
		var percent = values[port]
		var value = percentToRaw(percent)
		var realPercent = Double(percent)
		//HB returns raw values from sensors, while FL returns percentages.
		if type(of: robot).type == .Hummingbird {
			value = values[port]
			percent = UInt8(rawToPercent(value))
			realPercent = Double(value) / 2.55
		}
		
		var sensorValue: Int
		
		switch sensor {
		case "distance":
			sensorValue = rawToDistance(value)
		case "temperature":
			sensorValue = rawToTemp(value)
		case "soil":
			sensorValue = bound(Int(percent), min: 0, max: 90)
		default:
			return .ok(.text(String(realPercent)))
		}
		
		return .ok(.text(String(sensorValue)))
	}
	
	
	//MARK: Outputs for Hummingbirds
	
	private func setLEDRequest(id: String, type: BBTRobotType,
	                           request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		guard let portStr = queries["port"],
			let intensityStr = queries["intensity"],
			let port = Int(portStr),
			let intensity = UInt8(intensityStr) else {
			
			return .badRequest(.text("Missing or invalid parameters"))
		}
		
		let (roboto, requesto) = self.getRobotOrResponse(id: id, type: type,
		                                                 acceptTypes: [.Hummingbird])
		guard let robot = roboto else {
			return requesto!
		}
		
		if (robot as! HummingbirdPeripheral).setLED(port: port, intensity: intensity) {
			return .ok(.text("set"))
		} else {
			return .internalServerError
		}
	}
	
	private func setVibrationRequest(id: String, type: BBTRobotType,
	                                 request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		guard let portStr = queries["port"],
			let intensityStr = queries["intensity"],
			let port = Int(portStr),
			let intensity = UInt8(intensityStr) else {
				
				return .badRequest(.text("Missing or invalid parameters"))
		}
		
		let (roboto, requesto) = self.getRobotOrResponse(id: id, type: type,
		                                                 acceptTypes: [.Hummingbird])
		guard let robot = roboto else {
			return requesto!
		}
		
		if (robot as! HummingbirdPeripheral).setVibration(port: port, intensity: intensity) {
			return .ok(.text("set"))
		} else {
			return .internalServerError
		}
	}
	
	private func setMotorRequest(id: String, type: BBTRobotType,
	                             request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		guard let portStr = queries["port"],
			let speedStr = queries["speed"],
			let port = Int(portStr),
			let speed = Int(speedStr) else {
				
				return .badRequest(.text("Missing or invalid parameters"))
		}
		
		let (roboto, requesto) = self.getRobotOrResponse(id: id, type: type,
		                                                 acceptTypes: [.Hummingbird])
		guard let robot = roboto else {
			return requesto!
		}
		
		if (robot as! HummingbirdPeripheral).setMotor(port: port, speed: Int8(speed)) {
			return .ok(.text("set"))
		} else {
			return .internalServerError
		}
	}
	
	
	//MARK: Flutter outputs
	
	private func setBuzzerRequest(id: String, type: BBTRobotType,
	                              request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		guard let volumeStr = queries["volume"],
			let frequencyStr = queries["frequency"],
			let volume = Int(volumeStr),
			let frequency = Int(frequencyStr) else {
				
				return .badRequest(.text("Missing or invalid parameters"))
		}
		
		let (roboto, requesto) = self.getRobotOrResponse(id: id, type: type,
		                                                 acceptTypes: [.Flutter])
		guard let robot = roboto else {
			return requesto!
		}
		
		if (robot as! FlutterPeripheral).setBuzzer(volume: volume, frequency: frequency) {
			return .ok(.text("set"))
		} else {
			return .internalServerError
		}
	}
	
	//MARK: Finch Outputs
	//TODO: Delete
	private func setAll(id: String, type: BBTRobotType,
	                    request: HttpRequest) -> HttpResponse{
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		guard let dataStr = queries["data"] else {
			return .badRequest(.text("Missing Parameter"))
		}
		
		let (roboto, requesto) = self.getRobotOrResponse(id: id, type: type,
		                                                 acceptTypes: [.Finch])
		guard let robot = roboto else {
			return requesto!
		}
		
		let resps = (robot as! FinchPeripheral).setAll(str: dataStr)
		let ss = resps.map({String($0)})
		
		return .ok(.text(ss.joined(separator: ",")))
	}
}
