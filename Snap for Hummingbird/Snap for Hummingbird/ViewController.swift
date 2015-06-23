//
//  ViewController.swift
//  Snap for Hummingbird
//
//  Created by birdbrain on 6/5/15.
//  Copyright (c) 2015 Birdbrain Technologies LLC. All rights reserved.
//

import UIKit
import HummingbirdLibrary
import AVFoundation
import CoreLocation
import SystemConfiguration.CaptiveNetwork
import CoreMotion
import WebKit


class ViewController: UIViewController, CLLocationManagerDelegate {

    var hbServe: HummingbirdServices!
    let server: HttpServer = HttpServer()
    var wasShaken: Bool = false
    var shakenTimer: NSTimer = NSTimer()
    let locationManager = CLLocationManager()
    let altimeter = CMAltimeter()
    let motionManager = CMMotionManager()
    let synth = AVSpeechSynthesizer()
    
    var currentAltitude: Float = 0 //meters
    var currentPressure: Float = 0 //kPa
    var currentLocation:CLLocationCoordinate2D = CLLocationCoordinate2D()
    var x: Double = 0, y: Double = 0, z: Double = 0
    @IBOutlet weak var mainWebView: UIWebView!
    var webView: WKWebView?
    
    override func loadView() {
        super.loadView()
        self.webView = WKWebView()
        self.view = self.webView
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        prepareServer()
        server.start(listenPort: 22179, error: nil)
        navigationController!.setNavigationBarHidden(true, animated:true)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("changedStatus:"), name: BluetoothStatusChangedNotification, object: nil)
        
        self.locationManager.requestAlwaysAuthorization()
        self.locationManager.requestWhenInUseAuthorization()
        if (CLLocationManager.locationServicesEnabled()){
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.requestAlwaysAuthorization()
            locationManager.startUpdatingLocation()
        }
        
        if(CMAltimeter.isRelativeAltitudeAvailable()){
            altimeter.startRelativeAltitudeUpdatesToQueue(NSOperationQueue.mainQueue(), withHandler: {data, error in
                if(error == nil) {
                    self.currentAltitude = Float(data.relativeAltitude)
                    self.currentPressure = Float(data.pressure)
                }
            })
        }
        let queue = NSOperationQueue()
        self.motionManager.accelerometerUpdateInterval = 0.5
        if(self.motionManager.accelerometerAvailable) {
            self.motionManager.startAccelerometerUpdatesToQueue(queue, withHandler: {data, error in
                dispatch_async(dispatch_get_main_queue(), {
                    self.x = data.acceleration.x
                    self.y = data.acceleration.y
                    self.z = data.acceleration.z
                })
            })

        }
        let url = NSURL(string: "http://snap.berkeley.edu/snapsource/snap.html#cloud:Username=BirdBrainTech&ProjectName=HummingbirdStartiPad")
        let requestPage = NSURLRequest(URL: url!)
        webView?.contentMode = UIViewContentMode.ScaleAspectFit
        webView?.loadRequest(requestPage)
    }
    
    //for shake
    override func canBecomeFirstResponder() -> Bool {
        return true
    }
    override func motionEnded(motion: UIEventSubtype, withEvent event: UIEvent) {
        if (motion == UIEventSubtype.MotionShake){
            wasShaken = true
            shakenTimer = NSTimer.scheduledTimerWithTimeInterval(NSTimeInterval(5), target: self, selector: "expireShake", userInfo: nil, repeats: false)
        }
    }
    func expireShake(){
        wasShaken = false
        shakenTimer.invalidate()
    }
    func checkShaken() -> Bool{
        shakenTimer.invalidate()
        if wasShaken{
            wasShaken = false
            return true
        }
        return false
    }
    //end shake
    //location
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        currentLocation = manager.location.coordinate
    }
    //end location
    
    //get ssid
    func getSSIDInfo() -> CFDictionary?{
        if let
            ifs = CNCopySupportedInterfaces().takeUnretainedValue() as? [String],
            ifName = ifs.first,
            info = CNCopyCurrentNetworkInfo(ifName as CFStringRef)
        {
            return info.takeUnretainedValue()
        }
        return nil
    }
    //end ssid
    
    //start orientation
    func getOrientation() -> String{
        if(abs(self.x + 1) < 0.1){
            return "Landscape: home button on right"
        } else if(abs(self.x - 1) < 0.15){
            return "Landscape: home button on left"
        } else if(abs(self.y + 1) < 0.15){
            return "Portrait: home button on bottom"
        } else if(abs(self.y - 1) < 0.15){
            return "Portrait: home button on top"
        } else if(abs(self.z + 1) < 0.15){
            return "Faceup"
        } else if(abs(self.z - 1) < 0.15){
            return "Facedown"
        }
        return "In between"
    }
    //end orientation
    deinit{
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BluetoothStatusChangedNotification, object: nil)
    }
    func prepareServer(){
        server["/hummingbird/out/led/(.+)/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            let port = UInt8((captured[0]).toInt()!)
            let temp = Int(round((captured[1] as NSString).floatValue))
            var intensity: UInt8
            if (temp < 0){
                intensity = 0
            }
            else if (temp > 255){
                intensity = 255
            }
            else{
                intensity = UInt8(temp)
            }
            self.hbServe.setLED(port, intensity: intensity)
            return .OK(.RAW("LED set"))
        }
        server["/hummingbird/out/triled/(.+)/(.+)/(.+)/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            let port: UInt8 = UInt8(captured[0].toInt()!)
            var temp = Int(round((captured[1] as NSString).floatValue))
            var rValue: UInt8
            if (temp < 0){
                rValue = 0
            }
            else if (temp > 255){
                rValue = 255
            }
            else{
                rValue = UInt8(temp)
            }
            temp = Int(round((captured[2] as NSString).floatValue))
            var gValue: UInt8
            if (temp < 0){
                gValue = 0
            }
            else if (temp > 255){
                gValue = 255
            }
            else{
                gValue = UInt8(temp)
            }
            temp = Int(round((captured[3] as NSString).floatValue))
            var bValue: UInt8
            if (temp < 0){
                bValue = 0
            }
            else if (temp > 255){
                bValue = 255
            }
            else{
                bValue = UInt8(temp)
            }
            self.hbServe.setTriLED(port, r: rValue, g: gValue, b: bValue)
            return .OK(.RAW("Tri-LED set"))
        }
        server["/hummingbird/out/vibration/(.+)/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            let port: UInt8 = UInt8(captured[0].toInt()!)
            let temp = Int(round((captured[1] as NSString).floatValue))
            var intensity: UInt8
            if (temp < 0){
                intensity = 0
            }
            else if (temp > 100){
                intensity = 100
            }
            else{
                intensity = UInt8(temp)
            }
            
            self.hbServe.setVibration(port, intensity: intensity)
            return .OK(.RAW("Vibration set"))
        }
        server["/hummingbird/out/servo/(.+)/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            let port: UInt8 = UInt8(captured[0].toInt()!)
            
            let temp = Int(round((captured[1] as NSString).floatValue))
            var angle: UInt8
            if (temp < 0){
                angle = 0
            }
            else if (temp > 180 && temp != 255){
                angle = 180
            }
            else{
                angle = UInt8(temp)
            }
            
            self.hbServe.setServo(port, angle: angle)
            return .OK(.RAW("Servo set"))
        }
        server["/hummingbird/out/motor/(.+)/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            let port: UInt8 = UInt8(captured[0].toInt()!)
            let temp = Int(round((captured[1] as NSString).floatValue))
            var intensity: Int
            if (temp < -100){
                intensity = -100
            }
            else if (temp > 100){
                intensity = 100
            }
            else{
                intensity = temp
            }
            self.hbServe.setMotor(port, speed: intensity)
            return .OK(.RAW("Motor set"))
        }
        server["/hummingbird/in/sensors"] = { request in
            var sensorData = self.hbServe.getAllSensorDataFromPoll()
            var response: String = "" + String(rawto100scale(sensorData[0])) + " " + String(rawto100scale(sensorData[1])) + " " + String(rawto100scale(sensorData[2])) + " " + String(rawto100scale(sensorData[3]))
            return .OK(.RAW(response))
        }
        server["/hummingbird/in/sensor/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            var port = UInt8(captured[0].toInt()!)
            var sensorData = rawto100scale(self.hbServe.getSensorDataFromPoll(port))
            var response: String = String(sensorData)
            return .OK(.RAW(response))
        }
        server["/hummingbird/in/distance/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            var port = UInt8(captured[0].toInt()!)
            var sensorData = rawToDistance(self.hbServe.getSensorDataFromPoll(port))
            var response: String = String(sensorData)
            return .OK(.RAW(response))
        }
        server["/hummingbird/in/sound/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            var port = UInt8(captured[0].toInt()!)
            var sensorData = rawToSound(self.hbServe.getSensorDataFromPoll(port))
            var response: String = String(sensorData)
            return .OK(.RAW(response))
        }
        server["/hummingbird/in/temperature/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            var port = UInt8(captured[0].toInt()!)
            var sensorData = rawToTemp(self.hbServe.getSensorDataFromPoll(port))
            var response: String = String(sensorData)
            return .OK(.RAW(response))
        }
        server["/speak/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            var words = String(captured[0])
            var utterance = AVSpeechUtterance(string: words)
            utterance.rate = 0.3
            self.synth.speakUtterance(utterance)
            return .OK(.RAW(words))
            
        }
        server["/iPad/shake"] = {request in
            let checkShake = self.checkShaken()
            if checkShake{
                 return .OK(.RAW(String(1)))
            }
            return .OK(.RAW(String(0)))
        }
        server["/iPad/location"] = {request in
            let latitude = Double(self.currentLocation.latitude)
            let longitude = Double(self.currentLocation.longitude)
            let retString = NSString(format: "%f %f", latitude, longitude)
            return .OK(.RAW(String(retString)))
        }
        server["/iPad/ssid"] = {request in
            if let
            ssidInfo = self.getSSIDInfo() as? [String:AnyObject],
            ssid = ssidInfo["SSID"] as? String
            {
                return .OK(.RAW(ssid))
            } else{
                return .OK(.RAW(""))
            }
        }
        server["/iPad/pressure"] = {request in
            return .OK(.RAW(String(format: "%f", self.currentPressure)))
        }
        server["/iPad/altitude"] = {request in
            return .OK(.RAW(String(format: "%f", self.currentAltitude)))
        }
        server["/iPad/acceleration"] = {request in
            return .OK(.RAW(String(format: "%f %f %f", self.x, self.y, self.z)))
        }
        server["/iPad/orientation"] = {request in
            return .OK(.RAW(self.getOrientation()))
        }
    }
    func changedStatus(notification: NSNotification){
        let userinfo = notification.userInfo as! [String: Bool]
        if let isConnected: Bool = userinfo["isConnected"]{
            var statString = ""
            if isConnected{
                NSLog("device connected")
                statString = "Connected"
                hbServe.turnOffLightsMotor()
                NSThread.sleepForTimeInterval(0.1)
                hbServe.stopPolling()
                NSThread.sleepForTimeInterval(0.1)
                hbServe.beginPolling()
            }
            else{
                NSLog("device disconnected")
                statString = "Disconnected"

            }
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

