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

class HostDeviceRequests: NSObject, CLLocationManagerDelegate {
    
    let view_controller: ViewController
    
    var pingTimer: Timer = Timer()
    let locationManager = CLLocationManager()
    let altimeter = CMAltimeter()
    let motionManager = CMMotionManager()
    
    var currentAltitude: Float = 0 //meters
    var currentPressure: Float = 0 //kPa
    var currentLocation:CLLocationCoordinate2D = CLLocationCoordinate2D()
    var x: Double = 0, y: Double = 0, z: Double = 0
    
    var last_dialog_response: String?
    var last_choice_response = 0
    
    init(view_controller: ViewController){
        self.view_controller = view_controller
        super.init()
        if (CLLocationManager.locationServicesEnabled()){
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
        }
        
        if(CMAltimeter.isRelativeAltitudeAvailable()){
            altimeter.startRelativeAltitudeUpdates(to: OperationQueue.main, withHandler: {data, error in
                if(error == nil) {
                    self.currentAltitude = Float(data!.relativeAltitude)
                    self.currentPressure = Float(data!.pressure)
                }
            })
        }
        self.motionManager.accelerometerUpdateInterval = 0.5
        if(self.motionManager.isAccelerometerAvailable) {
            self.motionManager.startAccelerometerUpdates(to: OperationQueue(), withHandler: {data, error in
                DispatchQueue.main.async(execute: {
                    self.x = data!.acceleration.x
                    self.y = data!.acceleration.y
                    self.z = data!.acceleration.z
                })
            })
            
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
    
    func loadRequests(server: inout HttpServer){
        server["/tablet/shake"] = shakeRequest(request:)
        server["/tablet/location"] = locationRequest(request:)
        server["/tablet/ssid"] = ssidRequest(request:)
        server["/tablet/pressure"] = pressureRequest(request:)
        server["/tablet/altitude"] = altitudeRequest(request:)
        server["/tablet/orientation"] = orientationRequest(request:)
        server["/tablet/acceleration"] = accelerationRequest(request:)
        server["/tablet/dialog_response"] = dialogResponseRequest(request:)
        server["/tablet/choice_response"] = choiceResponseRequest(request:)
        
        server["/tablet/dialog/:title/:question/:holder"] = dialogRequest(request:)
        server["/tablet/choice/:title/:question/:button1/:button2"] = choiceRequest(request:)

        
        //TODO: This is hacky. For some reason, some requests don't
        // want to be pattern matched to properly
        let old_handler = server.notFoundHandler
        server.notFoundHandler = {
            r in
            if r.path == "/tablet/shake" {
                return self.shakeRequest(request: r)
            } else if r.path == "/tablet/location" {
                return self.locationRequest(request: r)
            } else if r.path == "/tablet/ssid" {
                return self.ssidRequest(request: r)
            } else if r.path == "/tablet/pressure" {
                return self.pressureRequest(request: r)
            } else if r.path == "/tablet/altitude" {
                return self.altitudeRequest(request: r)
            } else if r.path == "/tablet/orientation" {
                return self.orientationRequest(request: r)
            } else if r.path == "/tablet/acceleration" {
                return self.orientationRequest(request: r)
            } else if r.path == "/tablet/dialog_response" {
                return self.orientationRequest(request: r)
            } else if r.path == "/tablet/choice_response" {
                return self.orientationRequest(request: r)
            }
            if let handler = old_handler{
                return handler(r)
            } else {
                return .notFound
            }
        }
    }
    
    func shakeRequest(request: HttpRequest) -> HttpResponse {
        let checkShake = view_controller.checkShaken()
        if checkShake{
            return .ok(.text(String(1)))
        }
        return .ok(.text(String(0)))
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
        return .ok(.text(String(format: "%f", self.currentPressure)))
    }
    func altitudeRequest(request: HttpRequest) -> HttpResponse {
        return .ok(.text(String(format: "%f", self.currentAltitude)))
    }
    func orientationRequest(request: HttpRequest) -> HttpResponse {
        var orientation: String = "In between"
        if(abs(self.x + 1) < 0.1){
            orientation = "Landscape: home button on right"
        } else if(abs(self.x - 1) < 0.15){
            orientation = "Landscape: home button on left"
        } else if(abs(self.y + 1) < 0.15){
            orientation = "Portrait: home button on bottom"
        } else if(abs(self.y - 1) < 0.15){
            orientation = "Portrait: home button on top"
        } else if(abs(self.z + 1) < 0.15){
            orientation = "Faceup"
        } else if(abs(self.z - 1) < 0.15){
            orientation = "Facedown"
        }
        return .ok(.text(orientation))

    }
    func accelerationRequest(request: HttpRequest) -> HttpResponse {
        return .ok(.text(String(format: "%f %f %f", self.x, self.y, self.z)))
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
        let captured = request.params
        let title = (captured[":title"]?.removingPercentEncoding)!
        let question = (captured[":question"]?.removingPercentEncoding)!
        let answerHolder = (captured[":holder"]?.removingPercentEncoding)!
        let alertController = UIAlertController(title: title, message: question, preferredStyle: UIAlertControllerStyle.alert)
        let okayAction = UIAlertAction(title: "Okay", style: UIAlertActionStyle.default){
            (action) -> Void in
            if let textField: AnyObject = alertController.textFields?.first{
                if let response = (textField as! UITextField).text{
                    self.last_dialog_response = response;
                }
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel){
            (action) -> Void in
            self.last_dialog_response = "!~<!--CANCELLED-->~!"
        }
        alertController.addTextField{
            (txtName) -> Void in
            txtName.placeholder = answerHolder
        }
        alertController.addAction(okayAction)
        alertController.addAction(cancelAction)
        DispatchQueue.main.async{
            UIApplication.shared.keyWindow?.rootViewController!.present(alertController, animated: true, completion: nil)
        }
        return .ok(.text("Dialog Presented"))

    }
    func choiceRequest(request: HttpRequest) -> HttpResponse {
        self.last_choice_response = 0
        let captured = request.params
        let title = (captured[":title"]?.removingPercentEncoding)!
        let question = (captured[":question"]?.removingPercentEncoding)!
        let button1Text = (captured[":button1"]?.removingPercentEncoding)!
        let button2Text = (captured[":button2"]?.removingPercentEncoding)!
        let alertController = UIAlertController(title: title, message: question, preferredStyle: UIAlertControllerStyle.alert)
        let button1Action = UIAlertAction(title: button1Text, style: UIAlertActionStyle.default){
            (action) -> Void in
            self.last_choice_response = 1
        }
        let button2Action = UIAlertAction(title: button2Text, style: UIAlertActionStyle.default){
            (action) -> Void in
            self.last_choice_response = 2
        }
        alertController.addAction(button1Action)
        alertController.addAction(button2Action)
        DispatchQueue.main.async{
            UIApplication.shared.keyWindow?.rootViewController!.present(alertController, animated: true, completion: nil)
        }
        return .ok(.text("Choice Dialog Presented"))
    }
    
    
}
