//
//  ViewController.swift
//  Snap for Hummingbird
//
//  Created by birdbrain on 6/5/15.
//  Copyright (c) 2015 Birdbrain Technologies LLC. All rights reserved.
//

import UIKit
import AVFoundation
import CoreLocation
import SystemConfiguration.CaptiveNetwork
import CoreMotion
import WebKit


class ViewController: UIViewController, CLLocationManagerDelegate {

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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        prepareServer()
        server.start(listenPort: 22179, error: nil)
        navigationController!.setNavigationBarHidden(true, animated:true)

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
        let url = NSURL(string: "http://snap.berkeley.edu/snapsource/snap.html#cloud:Username=BirdBrainTech&ProjectName=iPadStart")
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

    func prepareServer(){
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
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

