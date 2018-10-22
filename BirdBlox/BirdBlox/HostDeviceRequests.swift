//
//  HostDeviceRequests.swift
//  BirdBlox
//
//  Created by birdbrain on 4/27/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import UIKit
//import Swifter
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
                if error == nil, let data = data {
                    //self.currentAltitude = Float(data!.relativeAltitude)
                    //self.currentPressure = Float(data!.pressure)
                    self.currentAltitude = Float(truncating: data.relativeAltitude)
                    self.currentPressure = Float(truncating: data.pressure)
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
        if let loc = manager.location {
            currentLocation = loc.coordinate
        }
    }
    
    //get ssid
    func getSSIDInfo() -> String{
        var currentSSID = "null"
        if let interfaces:CFArray = CNCopySupportedInterfaces() {
            for i in 0..<CFArrayGetCount(interfaces){
                let interfaceName: UnsafeRawPointer = CFArrayGetValueAtIndex(interfaces, i)
                let rec = unsafeBitCast(interfaceName, to: AnyObject.self)
                if let unsafeInterfaceData = CNCopyCurrentNetworkInfo("\(rec)" as CFString) {
                    let interfaceData = unsafeInterfaceData as Dictionary
                    for dictData in interfaceData {
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
        
        server["/tablet/dialog"] = dialogRequest(request:)
        server["/tablet/choice"] = choiceRequest(request:)
		server["/tablet/availableSensors"] = self.sensorAvailabilityRequest
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
	
        //var orientation: String = "In between"
        var orientation: String = "other"
        if(abs(accel.x + 1) < 0.1){
            //orientation = "Landscape: home button on right"
            //changed to Landscape: camera on left
            orientation = "landscape_left"
        } else if(abs(accel.x - 1) < 0.15){
            //orientation = "Landscape: home button on left"
            //changed to Landscape: camera on right
            orientation = "landscape_right"
        } else if(abs(accel.y + 1) < 0.15){
            //orientation = "Portrait: home button on bottom"
            //changed to Portrait: camera on top
            orientation = "portrait_top"
        } else if(abs(accel.y - 1) < 0.15){
            //orientation = "Portrait: home button on top"
            //changed to Portrait: camera on bottom
            orientation = "portrait_bottom"
        } else if(abs(accel.z + 1) < 0.15){
            //orientation = "Faceup"
            orientation = "faceup"
        } else if(abs(accel.z - 1) < 0.15){
            //orientation = "Facedown"
            orientation = "facedown"
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
	
    
    func dialogRequest(request: HttpRequest) -> HttpResponse {
        let captured = BBTSequentialQueryArrayToDict(request.queryParams)
		
        if let title = captured["title"], let question = captured["question"],
            let okText = captured["okText"], let cancelText = captured["cancelText"] {
			
			let answerHolder: String? = captured["placeholder"]
			let prefillText: String? = captured["prefill"]
			let shouldSelectAll = (captured["selectAll"] == "true") && (prefillText != nil)
            
            let bbtColor = UIColor(red: 32/255, green: 155/255, blue: 169/255, alpha: 1.0)
			
			let alertController = UIAlertController(title: title, message: question,
			                                        preferredStyle: UIAlertController.Style.alert)
            
            alertController.setValue(NSAttributedString(string: title, attributes: convertToOptionalNSAttributedStringKeyDictionary([convertFromNSAttributedStringKey(NSAttributedString.Key.font) : UIFont.systemFont(ofSize: 20, weight: UIFont.Weight.bold), convertFromNSAttributedStringKey(NSAttributedString.Key.foregroundColor) : bbtColor])), forKey: "attributedTitle")
            alertController.setValue(NSAttributedString(string: question, attributes: convertToOptionalNSAttributedStringKeyDictionary([convertFromNSAttributedStringKey(NSAttributedString.Key.font) : UIFont.systemFont(ofSize: 14, weight: UIFont.Weight.medium), convertFromNSAttributedStringKey(NSAttributedString.Key.foregroundColor) : bbtColor])), forKey: "attributedMessage")
            
			let okayAction = UIAlertAction(title: okText, style: UIAlertAction.Style.default){
				(action) -> Void in
				if let textField: AnyObject = alertController.textFields?.first{
					let response = (textField as! UITextField).text
					if let response = response {
						let pr = FrontendCallbackCenter.shared.dialogPromptResponded
						let _ = pr(false, response)
					}
				}
			}
			
			let cancelAction = UIAlertAction(title: cancelText, style: UIAlertAction.Style.cancel){
				(action) -> Void in
				let _ = FrontendCallbackCenter.shared.dialogPromptResponded(cancelled: true,
				                                                            response: nil)
			}
			
			DispatchQueue.main.async{

				alertController.addTextField {
					(txtName) -> Void in
					txtName.placeholder = answerHolder
					txtName.text = prefillText
					txtName.clearButtonMode = .whileEditing
                    txtName.textColor = bbtColor
				}
				
				alertController.addAction(okayAction)
				alertController.addAction(cancelAction)
				
				UIApplication.shared.keyWindow?.rootViewController!.present(alertController,
				                                                            animated: true) {
					if shouldSelectAll {
						let field = alertController.textFields![0]
						field.selectedTextRange = field.textRange(from: field.beginningOfDocument,
																  to: field.endOfDocument)
					}
				}
                
                
                alertController.view.tintColor = bbtColor
                
			}
			return .ok(.text("Dialog Presented"))
		}
		
		return .badRequest(.text("Malformed request"))
    }
	
    func choiceRequest(request: HttpRequest) -> HttpResponse {
        let captured = BBTSequentialQueryArrayToDict(request.queryParams)
		
		let title = captured["title"] ?? ""
		
        if let question = (captured["question"]),
			let button1Text = (captured["button1"]){
			
			let alertController = UIAlertController(title: title, message: question,
			                                        preferredStyle: UIAlertController.Style.alert)
			let button1Action = UIAlertAction(title: button1Text, style: UIAlertAction.Style.default){
				(action) -> Void in
				let _ = FrontendCallbackCenter.shared.choiceResponded(cancelled: false,
				                                                      firstSelected: true)
			}
			alertController.addAction(button1Action)
			
			if let button2Text = captured["button2"] {
				let button2Action = UIAlertAction(title: button2Text, style: UIAlertAction.Style.default){
					(action) -> Void in
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


// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}
