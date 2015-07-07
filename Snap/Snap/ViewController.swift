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
    var webView: UIWebView?
    
    override func loadView() {
        super.loadView()
        self.webView = UIWebView()
        self.view = self.webView
    }
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    func isConnectedToInternet() -> Bool{
        var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        zeroAddress.sin_len = UInt8(sizeofValue(zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let defaultRouteReachability = withUnsafePointer(&zeroAddress) {
            SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0)).takeRetainedValue()
        }
        
        var flags: SCNetworkReachabilityFlags = 0
        if SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) == 0 {
            return false
        }
        
        let isReachable = (flags & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        
        return isReachable && !needsConnection
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        prepareServer()
        server.start(listenPort: 22180)

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
                    self.currentAltitude = Float(data!.relativeAltitude)
                    self.currentPressure = Float(data!.pressure)
                }
            })
        }
        let queue = NSOperationQueue()
        self.motionManager.accelerometerUpdateInterval = 0.5
        if(self.motionManager.accelerometerAvailable) {
            self.motionManager.startAccelerometerUpdatesToQueue(queue, withHandler: {data, error in
                dispatch_async(dispatch_get_main_queue(), {
                    self.x = data!.acceleration.x
                    self.y = data!.acceleration.y
                    self.z = data!.acceleration.z
                })
            })

        }
    }
    
    override func viewDidAppear(animated: Bool) {
        if(isConnectedToInternet()){
            let url = NSURL(string: "http://snap.berkeley.edu/snapsource/snap.html#open:http://localhost:22180/project.xml")
            let requestPage = NSURLRequest(URL: url!)
            
            webView?.contentMode = UIViewContentMode.ScaleAspectFit
            
            webView?.loadRequest(requestPage)
        }
        else{
            println("No Internet")
            let noConnectionAlert = UIAlertController(title: "Cannot Connect", message: "This app required an internet connection to work. There is currently no connection avaliable. A cached version of the web page will be opened if avaliable.", preferredStyle: UIAlertControllerStyle.Alert)
            noConnectionAlert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
            self.presentViewController(noConnectionAlert, animated: true, completion: nil)
            let url = NSURL(string: "http://snap.berkeley.edu/snapsource/snap.html#open:http://localhost:22180/project.xml")
            let requestPage = NSURLRequest(URL: url!)
            
            webView?.contentMode = UIViewContentMode.ScaleAspectFit
            
            webView?.loadRequest(requestPage)
        }
    }
    
    //for shake
    override func canBecomeFirstResponder() -> Bool {
        return true
    }
    override func motionEnded(motion: UIEventSubtype, withEvent event: UIEvent?) {
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
        currentLocation = manager.location!.coordinate
    }
    //end location
    
    //get ssid
    func getSSIDInfo() -> String{
        var ssid:NSString = "null"
        let ifs:NSArray = CNCopySupportedInterfaces().takeUnretainedValue() as NSArray
        for ifName: NSString in ifs as! [NSString]{
            let info: NSDictionary = CNCopyCurrentNetworkInfo(ifName).takeUnretainedValue()
            if (info["SSID"] != nil){
                ssid = info["SSID"] as! NSString
            }
        }
        return ssid as String
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
            let words = String(captured[0])
            let utterance = AVSpeechUtterance(string: words)
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
            let ssid = self.getSSIDInfo()
            return .OK(.RAW(ssid))
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
        server["/project.xml"] = {request in
            let path = NSBundle.mainBundle().pathForResource("iPadstart", ofType: "xml")
            let rawText = String(contentsOfFile: path!, encoding: NSUTF8StringEncoding, error: nil)
            
            return .OK(.RAW(rawText!))
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

