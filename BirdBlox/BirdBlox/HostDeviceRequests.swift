//
//  HostDeviceRequests.swift
//  BirdBlox
//
//  Created by birdbrain on 4/27/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import Swifter
import CoreLocation
import CoreMotion
import SystemConfiguration.CaptiveNetwork

class HostDeviceManager: NSObject, CLLocationManagerDelegate {
    
    let view_controller: BBTWebViewController
    
    var pingTimer: Timer = Timer()
    let locationManager = CLLocationManager()
    let altimeter = CMAltimeter()
    let motionManager = CMMotionManager()
    
    var currentAltitude: Float = 0 //meters
    var currentPressure: Float = 0 //kPa
    var currentLocation:CLLocationCoordinate2D = CLLocationCoordinate2D()
    
    var last_dialog_response: String?
    var last_choice_response = 0
    
    init(view_controller: BBTWebViewController){
        self.view_controller = view_controller
        super.init()
        if (CLLocationManager.locationServicesEnabled()){
            self.locationManager.delegate = self
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
            self.locationManager.requestWhenInUseAuthorization()
            self.locationManager.startUpdatingLocation()
        }
        
        if(CMAltimeter.isRelativeAltitudeAvailable()){
            altimeter.startRelativeAltitudeUpdates(to: OperationQueue.main,
                                                   withHandler: { data, error in
                if(error == nil) {
                    self.currentAltitude = Float(data!.relativeAltitude)
                    self.currentPressure = Float(data!.pressure)
                }
            })
        }
		if self.motionManager.isDeviceMotionAvailable {
			self.motionManager.startDeviceMotionUpdates()
		} else if(self.motionManager.isAccelerometerAvailable) {
			self.motionManager.startAccelerometerUpdates()
		}
	}
	
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = manager.location!.coordinate
    }
    
    //get ssid
    func getSSIDInfo() -> String{
        var currentSSID = "null"
        if let interfaces:CFArray = CNCopySupportedInterfaces() {
            for i in 0..<CFArrayGetCount(interfaces){
                let interfaceName: UnsafeRawPointer = CFArrayGetValueAtIndex(interfaces, i)
                let rec = unsafeBitCast(interfaceName, to: AnyObject.self)
                let unsafeInterfaceData = CNCopyCurrentNetworkInfo("\(rec)" as CFString)
                if unsafeInterfaceData != nil {
                    let interfaceData = unsafeInterfaceData! as Dictionary!
                    for dictData in interfaceData! {
                        if dictData.key as! String == "SSID" {
                            currentSSID = dictData.value as! String
                        }
                    }
                }
            }
        }
        return currentSSID
    }
    //end ssid
    
    func loadRequests(server: BBTBackendServer){
        server["/tablet/location"] = locationRequest(request:)
        server["/tablet/ssid"] = ssidRequest(request:)
        server["/tablet/pressure"] = pressureRequest(request:)
        server["/tablet/altitude"] = altitudeRequest(request:)
        server["/tablet/orientation"] = orientationRequest(request:)
        server["/tablet/acceleration"] = accelerationRequest(request:)
        server["/tablet/dialog_response"] = dialogResponseRequest(request:)
        server["/tablet/choice_response"] = choiceResponseRequest(request:)
        
        server["/tablet/dialog"] = dialogRequest(request:)
        server["/tablet/choice"] = choiceRequest(request:)
		server["/tablet/availableSensors"] = self.sensorAvailabilityRequest
		
//		// /tablet/dialog?title=x&question=y&holder=z
//		server["/tablet/dialog"] = self.dialogRequest
//		
//		// /tablet/choice?title=x&question=y&button1=z&button2=q
//		server["/tablet/choice"] = self.choiceRequest
    }
	
	func sensorAvailabilityRequest(request: HttpRequest) -> HttpResponse {
		let alt = CMAltimeter.isRelativeAltitudeAvailable()
		var responseString = ""
		responseString = responseString + BBXCallbackManager.Sensor.Accelerometer.jsString() + "\n"
		responseString = responseString + BBXCallbackManager.Sensor.GPSReceiver.jsString() + "\n"
		responseString = responseString + BBXCallbackManager.Sensor.Microphone.jsString() + "\n"
		if alt {
			responseString = responseString + BBXCallbackManager.Sensor.Barometer.jsString() + "\n"
		} else {
			print("no barometer")
		}
		
		return .ok(.text(responseString))
	}
	
    func locationRequest(request: HttpRequest) -> HttpResponse {
        let latitude = Double(self.currentLocation.latitude)
        let longitude = Double(self.currentLocation.longitude)
        let retString = NSString(format: "%f %f", latitude, longitude)
        return .ok(.text(String(retString)))
    }
    func ssidRequest(request: HttpRequest) -> HttpResponse {
        let ssid = self.getSSIDInfo()
        return .ok(.text(ssid))
    }
    func pressureRequest(request: HttpRequest) -> HttpResponse {
		guard CMAltimeter.isRelativeAltitudeAvailable() else {
			return .badRequest(.text("No barometer available"))
		}
        return .ok(.text(String(format: "%f", self.currentPressure)))
    }
    func altitudeRequest(request: HttpRequest) -> HttpResponse {
		guard CMAltimeter.isRelativeAltitudeAvailable() else {
			return .badRequest(.text("No barometer available"))
		}
        return .ok(.text(String(format: "%f", self.currentAltitude)))
    }
    func orientationRequest(request: HttpRequest) -> HttpResponse {
		guard let accel = self.acceleration else {
			return .internalServerError
		}
	
        var orientation: String = "In between"
        if(abs(accel.x + 1) < 0.1){
            orientation = "Landscape: home button on right"
        } else if(abs(accel.x - 1) < 0.15){
            orientation = "Landscape: home button on left"
        } else if(abs(accel.y + 1) < 0.15){
            orientation = "Portrait: home button on bottom"
        } else if(abs(accel.y - 1) < 0.15){
            orientation = "Portrait: home button on top"
        } else if(abs(accel.z + 1) < 0.15){
            orientation = "Faceup"
        } else if(abs(accel.z - 1) < 0.15){
            orientation = "Facedown"
        }
		
        return .ok(.text(orientation))
    }
	
	//Gives us the current acceleration in G's
	fileprivate var acceleration: CMAcceleration! {
		var currentAccel: CMAcceleration! = nil
		
		if self.motionManager.isDeviceMotionActive {
			if let grav = self.motionManager.deviceMotion?.gravity,
				let user = self.motionManager.deviceMotion?.userAcceleration {
				currentAccel = CMAcceleration(x: grav.x + user.x, y: grav.y + user.y,
				                              z: grav.z + user.z)
			}
		} else if self.motionManager.isAccelerometerActive {
			currentAccel = self.motionManager.accelerometerData?.acceleration
		}
		
		return currentAccel
	}
	
    func accelerationRequest(request: HttpRequest) -> HttpResponse {
		guard let accel = self.acceleration else {
			return .internalServerError
		}
		//We convert from G's to ms^-2 by multiplying by 9.81
		return .ok(.text("\(accel.x * 9.81) \(accel.y * 9.81) \(accel.z * 9.81)"))
    }
    func dialogResponseRequest(request: HttpRequest) -> HttpResponse {
        if let response = self.last_dialog_response {
            if (response == "!~<!--CANCELLED-->~!") {
                return .ok(.text("Cancelled"))
            } else {
                return .ok(.text("\'" + response + "\'"))
            }
        }
        else {
            return .ok(.text("No Response"))
        }
    }
    func choiceResponseRequest(request: HttpRequest) -> HttpResponse {
        return .ok(.text(String(self.last_choice_response)))
    }
    
    func dialogRequest(request: HttpRequest) -> HttpResponse {
        self.last_dialog_response = nil
        let captured = BBTSequentialQueryArrayToDict(request.queryParams)
		
        if let title = (captured["title"]),
			let question = (captured["question"]) {
			
			let answerHolder: String? = (captured["placeholder"])
			let prefillText: String? = captured["prefill"]
			let shouldSelectAll = (captured["selectAll"] == "true") && (prefillText != nil)
			
			let alertController = UIAlertController(title: title, message: question,
			                                        preferredStyle: UIAlertControllerStyle.alert)
			let okayAction = UIAlertAction(title: "Okay", style: UIAlertActionStyle.default){
				(action) -> Void in
				if let textField: AnyObject = alertController.textFields?.first{
					let response = (textField as! UITextField).text
					if let response = response {
						self.last_dialog_response = response;
					}
					
					let _ = FrontendCallbackCenter.shared.dialogPromptResponded(cancelled: false,
					                                                            response: response)
				}
			}
			
			let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel){
				(action) -> Void in
				self.last_dialog_response = "!~<!--CANCELLED-->~!"
				let _ = FrontendCallbackCenter.shared.dialogPromptResponded(cancelled: true,
				                                                            response: nil)
			}
			
			alertController.addTextField{
				(txtName) -> Void in
				txtName.placeholder = answerHolder
				txtName.text = prefillText
				txtName.clearButtonMode = .whileEditing
			}
			
			alertController.addAction(okayAction)
			alertController.addAction(cancelAction)
			
			DispatchQueue.main.async{
				UIApplication.shared.keyWindow?.rootViewController!.present(alertController,
				                                                            animated: true) {
					if shouldSelectAll {
						let field = alertController.textFields![0]
						field.selectedTextRange = field.textRange(from: field.beginningOfDocument,
																  to: field.endOfDocument)
					}
				}
			}
			return .ok(.text("Dialog Presented"))
		}
		
		return .badRequest(.text("Malformed request"))
    }
	
    func choiceRequest(request: HttpRequest) -> HttpResponse {
        self.last_choice_response = 0
        let captured = BBTSequentialQueryArrayToDict(request.queryParams)
		
        if let title = (captured["title"]),
			let question = (captured["question"]),
			let button1Text = (captured["button1"]){
			
			let alertController = UIAlertController(title: title, message: question,
			                                        preferredStyle: UIAlertControllerStyle.alert)
			let button1Action = UIAlertAction(title: button1Text, style: UIAlertActionStyle.default){
				(action) -> Void in
				self.last_choice_response = 1
				let _ = FrontendCallbackCenter.shared.choiceResponded(cancelled: false,
				                                                      firstSelected: true)
			}
			alertController.addAction(button1Action)
			
			if let button2Text = captured["button2"] {
				let button2Action = UIAlertAction(title: button2Text, style: UIAlertActionStyle.default){
					(action) -> Void in
					self.last_choice_response = 2
					let _ = FrontendCallbackCenter.shared.choiceResponded(cancelled: false,
																		  firstSelected: false)
				}
				alertController.addAction(button2Action)
			}
			
			DispatchQueue.main.async{
				UIApplication.shared.keyWindow?.rootViewController!.present(alertController,
				                                                            animated: true,
																			completion: nil)
			}
			return .ok(.text("Choice Dialog Presented"))
		}
		
		return .badRequest(.text("Malformed request"))
		
    }
	
	
}

