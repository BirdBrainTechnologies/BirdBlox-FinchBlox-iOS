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
        
        server["/robot/out/ledArray"] =
            RobotRequests.handler(fromIDAndTypeHandler: self.setLedArrayRequest)
        server["/robot/out/printBlock"] =
            RobotRequests.handler(fromIDAndTypeHandler: self.setLedArrayRequest)
		
		server["/robot/in"] = RobotRequests.handler(fromIDAndTypeHandler: self.inputRequest)
		
		server["/robot/showInfo"] = RobotRequests.handler(fromIDAndTypeHandler: self.infoRequest)
		
		//TODO: Delete (just for finch testing)
		server["/robot/out/setAll"] = RobotRequests.handler(fromIDAndTypeHandler: self.setAll)
	}
	
	private func discoverRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		print("Discover request received.")
		guard let typeStr = queries[RobotRequests.robotTypeKey] else {
			return .badRequest(.text("Missing Query Parameter"))
		}
		
		guard let type = BBTRobotType.fromString(typeStr) else {
			return .badRequest(.text("Invalid robot type: \(typeStr)"))
		}
		
		bleCenter.startScan(serviceUUIDs: [type.scanningUUID], updateDiscovered: { (peripherals) in
			let altName = "Fetching name..."
            let filteredList = peripherals.filter { $0.2 == type }
			let darray = filteredList.map { (peripheral, rssi, type) in
				["id": peripheral.identifier.uuidString,
				 "name": BBTgetDeviceNameForGAPName(peripheral.name ?? altName),
                 //"device": BBTRobotType.fromString(peripheral.name ?? altName)?.description ?? altName,
                 "device": type.description,
                 "RSSI": rssi]
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
		
		return .ok(.text("Issued stop commands to every connected device."))
	}
	
	private func getRobotOrResponse(id: String, type: BBTRobotType, acceptTypes: [BBTRobotType])
	 -> (BBTRobotBLEPeripheral?, HttpResponse?) {
		guard let robot = bleCenter.robotForID(id) else {
			return (nil, .notFound)
		}
		
		guard robot.type == type else {
			return (nil,.badRequest(.text("Type of robot does not match type passed in parameter")))
		}
		
		guard acceptTypes.contains(robot.type) else {
			return (nil, .badRequest(.text("Operation not supported by type")))
		}
		
		return (robot, nil)
	}
	
	private func inputRequest(id: String, type: BBTRobotType,
	                          request: HttpRequest) -> HttpResponse {
        
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		guard let sensor = queries["sensor"] else {
            return .badRequest(.text("Malformed Request - sensor type missing"))
		}
		
		let (roboto, requesto) = self.getRobotOrResponse(id: id, type: type,
		                                                 acceptTypes: [.Flutter, .Hummingbird, .HummingbirdBit, .Finch, .MicroBit])
		guard let robot = roboto else {
			return requesto!
		}
		
		let values = robot.sensorValues
		var sensorValue: String
        
        //The accelerometer values are used for multiple blocks
        let accelerometerAdjust: ((UInt8) -> Double) = { x in
            let intVal = Int8(bitPattern: x) //convert to 2's complement signed int
            let scaledVal = Double(intVal) * 196/1280 //scaling from bambi
            print("ACCELEROMETER VALUES! \(x) \(intVal) \(scaledVal)")
            return scaledVal
        }
		
		switch sensor {
        
        //Screen up and Screen down are z: Acc Z > 0.8*g screen down, Acc Z < -0.8*g screen up
        //Tilt left and tilt right are x: Acc X > 0.8g tilt left, Acc X < -0.8g tilt right
        //Logo up and logo down are y: Acc Y > 0.8g logo down, Acc Y < -0.8g logo up
        case "screenUp":
            let val = accelerometerAdjust(values[6])
            if val < -0.8 {sensorValue = String(1)} else {sensorValue = String(0)}
        case "screenDown":
            let val = accelerometerAdjust(values[6])
            if val > 0.8 {sensorValue = String(1)} else {sensorValue = String(0)}
        case "tiltLeft":
            let val = accelerometerAdjust(values[4])
            if val > 0.8 {sensorValue = String(1)} else {sensorValue = String(0)}
        case "tiltRight":
            let val = accelerometerAdjust(values[4])
            if val < -0.8 {sensorValue = String(1)} else {sensorValue = String(0)}
        case "logoUp":
            let val = accelerometerAdjust(values[5])
            if val < -0.8 {sensorValue = String(1)} else {sensorValue = String(0)}
        case "logoDown":
            let val = accelerometerAdjust(values[5])
            if val > 0.8 {sensorValue = String(1)} else {sensorValue = String(0)}
            
        case "buttonA", "buttonB", "shake": //microbit buttons and shake
            let buttonShake = values[7]
            let bsBitValues = byteToBits(buttonShake)
            //TODO: should the buttons return true when pressed?
            switch sensor {
            case "buttonA": sensorValue = String(bsBitValues[4])
            case "buttonB": sensorValue = String(bsBitValues[5])
            case "shake": sensorValue = String(bsBitValues[0])
            default: return .badRequest(.text("sensor not specified correctly"))
            }
            
        //TODO: add a check to make sure there is an accelerometer or magnetometer when requested
        case "accelerometer": 
            guard let axis = queries["axis"] else {
                return .badRequest(.text("Accelerometer axis not specified."))
            }
            
            switch axis {
            case "x": sensorValue = String(accelerometerAdjust(values[4]))
            case "y": sensorValue = String(accelerometerAdjust(values[5]))
            case "z": sensorValue = String(accelerometerAdjust(values[6]))
            default:
                return .badRequest(.text("Accelerometer axis incorrectly specified as \(axis)"))
            }
        case "magnetometer":
            guard let axis = queries["axis"] else {
                return .badRequest(.text("Accelerometer axis not specified."))
            }
            let adjust: ((UInt8, UInt8) -> String) = { msb, lsb in
                let uIntVal = (UInt16(msb) << 8) | UInt16(lsb)
                let intVal = Int16(bitPattern: uIntVal)
                print( "MAGNETOMETER VALUES! \(msb) \(lsb) \(uIntVal) \(intVal)" )
                return String( intVal / 10 ) //TODO: check
            }
            let x = adjust(values[8], values[9])
            let y = adjust(values[10], values[11])
            let z = adjust(values[12], values[13])
            switch axis {
            case "x": sensorValue = x
            case "y": sensorValue = y
            case "z": sensorValue = z
            case "all": sensorValue = "\(x) \(y) \(z)"
            default:
                return .badRequest(.text("Accelerometer axis not specified."))
            }
		default:
            //For hummingbird type sensors, a port will be specified.
            //These sensor values will be in the first 4 value array spots.
            guard let portStr = queries["port"], var port = Int(portStr) else {
                return .badRequest(.text("Malformed Request - port not specified."))
            }
            
            port -= 1
            guard port < robot.type.sensorPortCount && port >= 0 else {
                return .badRequest(.text("Port is out of bounds"))
            }
            
            let value = values[port]
            let percent = UInt8(rawToPercent(value))
            let realPercent = Double(value) / 2.55
            
            switch sensor {
            case "dial":
                var scaledVal = Int( Double(value) * (100 / 230) )
                if scaledVal > 100 { scaledVal = 100 }
                sensorValue = String(scaledVal)
            case "distance":
                sensorValue = String(rawToDistance(value))
            case "temperature":
                sensorValue = String(rawToTemp(value))
            case "soil":
                sensorValue = String(bound(Int(percent), min: 0, max: 90))
            case "sound":
                if robot.type == .HummingbirdBit {
                    sensorValue = String(value * (200/255)) //scaling from bambi
                } else {
                    sensorValue = String(realPercent) //TODO: should this really be different?
                }
            default:
                return .ok(.text(String(realPercent)))
            }
		}
		
		return .ok(.text(sensorValue))
	}
	
	
	//MARK: Outputs
    
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
                                                         acceptTypes: [.Hummingbird, .HummingbirdBit, .Finch, .Flutter])
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
            let port = UInt(portStr)  else {
                return .badRequest(.text("Missing or invalid port"))
        }
        
        //sending 255 turns it off
        var value: UInt8 = 0
        if let angleStr = queries["angle"], let angle = UInt8(angleStr) {
            //let adjustServo: ((UInt8) -> UInt8) = { ($0 > 180) ? 255 : $0 + ($0 >> 2) }
            switch type {
            case .Hummingbird:
                let adjustServo: ((UInt8) -> UInt8) = { ($0 > 180) ? 255 : $0 + ($0 >> 2) }
                value = adjustServo(angle)
            case .HummingbirdBit:
                if angle > 180 { value = UInt8(254)
                } else {
                    value = UInt8( angle * (254 / 180) )
                }
            default: fatalError("position servo not set up for type \(type)")
            }
            //This is only for rotation servos. Currently only available in hummingbird bit
        } else if let percentStr = queries["percent"], let percent = Int(percentStr) {
            if percent >= -10 && percent <= 10 { value = UInt8(255) //off signal
            } else if percent > 100 { value = UInt8(254)
            } else if percent < -100 { value = UInt8(0)
            } else { value = UInt8( ( (percent * 23) / 100 ) + 122 ) } //from bambi
        } else {
            return .badRequest(.text("Missing or invalid parameter"))
        }
        
        let (roboto, requesto) = self.getRobotOrResponse(id: id, type: type,
                                                         acceptTypes: [.Hummingbird, .HummingbirdBit, .Flutter])
        guard let robot = roboto else {
            return requesto!
        }
        
        if robot.setServo(port: port, value: value) {
            return .ok(.text("set"))
        } else {
            return .internalServerError
        }
    }
	
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
		                                                 acceptTypes: [.Hummingbird, .HummingbirdBit])
		guard let robot = roboto else {
			return requesto!
		}
		
		if robot.setLED(port: port, intensity: intensity) {
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
		
		if robot.setVibration(port: port, intensity: intensity) {
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
		                                                 acceptTypes: [.Hummingbird, .Finch])
		guard let robot = roboto else {
			return requesto!
		}
		
		if robot.setMotor(port: port, speed: Int8(speed)) {
			return .ok(.text("set"))
		} else {
			return .internalServerError
		}
	}
	
	
	private func setBuzzerRequest(id: String, type: BBTRobotType,
	                              request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
            
        guard let noteStr = queries["note"], let durationStr = queries["duration"],
            let note = UInt8(noteStr), let exactDur = Double(durationStr) else {
            return .badRequest(.text("Missing or invalid parameters"))
        }
        
        let (roboto, requesto) = self.getRobotOrResponse(id: id, type: type,
                                                         acceptTypes: [.Finch, .HummingbirdBit])
        guard let robot = roboto else {
            return requesto!
        }
        
        let duration = UInt16(round(exactDur))
        let period = noteToPeriod(note)
        if robot.setBuzzer(volume: 0, frequency: 0, period: period, duration: duration) {
            return .ok(.text("set"))
        } else {
            return .internalServerError
        }
        
	}
	
    private func setLedArrayRequest(id: String, type: BBTRobotType,
                                  request: HttpRequest) -> HttpResponse {
        let queries = BBTSequentialQueryArrayToDict(request.queryParams)
        var ledStatusString : String
        
        if request.path.contains("printBlock") {
            guard let printString = queries["printString"] else {
                return .badRequest(.text("String to print not specified."))
            }
            
            ledStatusString = "F" + String(printString.prefix(18)).uppercased()
        } else if request.path.contains("ledArray") {
            guard let ledArrayStatus = queries["ledArrayStatus"] else {
                return .badRequest(.text("Missing or invalid parameters in set led array request"))
            }
            ledStatusString = "S" + ledArrayStatus
        } else {
            return .badRequest(.text("Specify printBlock or ledArray when setting the array"))
        }
        
        let (roboto, requesto) = self.getRobotOrResponse(id: id, type: type,
                                                         acceptTypes: [.MicroBit    , .HummingbirdBit])
        
        guard let robot = roboto else {
            return requesto!
        }
        
        //print("led array string: \(ledStatusString)")
        if robot.setLedArray(ledStatusString) {
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
		
		let resps = robot.setAll(str: dataStr)
		let ss = resps.map({String($0)})
		
		return .ok(.text(ss.joined(separator: ",")))
	}
}
