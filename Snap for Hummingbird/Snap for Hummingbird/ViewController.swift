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
import MessageUI

class ViewController: UIViewController, CLLocationManagerDelegate, WKUIDelegate, MFMailComposeViewControllerDelegate {
    
    @IBOutlet weak var importButton: UIButton!
    let responseTime = 0.001
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
    var mainWebView : WKWebView!
    var importedXMLText: String?
    

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
    func webView(webView: WKWebView, createWebViewWithConfiguration configuration: WKWebViewConfiguration, forNavigationAction navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if(navigationAction.targetFrame == nil){
            NSURLConnection.sendAsynchronousRequest(navigationAction.request, queue: NSOperationQueue.mainQueue()) {
                response, text, error in
                var mailComposer = MFMailComposeViewController()
                mailComposer.mailComposeDelegate = self
                mailComposer.title = "My Snap Project"
                let mineType: String = "text/xml"
                if(response.MIMEType?.pathComponents[1] == "xml"){
                    mailComposer.addAttachmentData(text, mimeType: mineType, fileName: "project.xml")
                    self.presentViewController(mailComposer, animated: true, completion: nil)
                }
                return
            }
        }
        return nil
    }
    
    func mailComposeController(controller: MFMailComposeViewController!, didFinishWithResult result: MFMailComposeResult, error: NSError!) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }

    override func loadView() {
        super.loadView()
        mainWebView = WKWebView(frame: self.view.bounds)
        mainWebView.UIDelegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardDidShow:", name: UIKeyboardDidShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardDidHide:", name: UIKeyboardDidHideNotification, object: nil)
        
        prepareServer()
        server.start(listenPort: 22179)
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
    
        mainWebView?.contentMode = UIViewContentMode.ScaleAspectFit
        if(isConnectedToInternet()){
            if(shouldUpdate()){
                getUpdate()
                
            }
            if let ip = getWiFiAddress(){
                let connectionAlert = UIAlertController(title: "Connected", message: "The app is currently connecting to a local version of Snap!. If would like to use the app as a server, simply open the iPad starter project or a project built from it on a computer and use this IP address: " + getWiFiAddress()!, preferredStyle: UIAlertControllerStyle.Alert)
                connectionAlert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
                self.presentViewController(connectionAlert, animated: true, completion: nil)
            }
            else{
                let connectionAlert = UIAlertController(title: "Connected", message: "The app is currently connecting to a local version of Snap!. If would like to use the app as a server, you need to be connected to wifi. Either you are not connected to wifi or have some connection connection issues.", preferredStyle: UIAlertControllerStyle.Alert)
                connectionAlert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
                self.presentViewController(connectionAlert, animated: true, completion: nil)
            }
            let url = NSURL(string: "http://localhost:22179/snap/snap.html#open:http://localhost:22179/project.xml")
            let requestPage = NSURLRequest(URL: url!)
            self.view.addSubview(mainWebView)
            mainWebView?.loadRequest(requestPage)
        }
        else{
            let noConnectionAlert = UIAlertController(title: "Cannot Connect", message: "This app required an internet connection for certain features to work. There is currently no connection avaliable. If this is your first time opening the app, it will NOT load. You need to open the app while you have internet at least once so that the snap source code can be downloaded", preferredStyle: UIAlertControllerStyle.Alert)
            noConnectionAlert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
            self.presentViewController(noConnectionAlert, animated: true, completion: nil)
            let url = NSURL(string: "http://localhost:22179/snap/snap.html#open:http://localhost:22179/project.xml")
            let requestPage = NSURLRequest(URL: url!)
            self.view.addSubview(mainWebView)
            mainWebView?.loadRequest(requestPage)
        }
        self.view.bringSubviewToFront(importButton)
    }
    
    var scrollingTimer = NSTimer()
    func keyboardDidShow(notification:NSNotification){
        scrollingTimer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: Selector("scrollToTop"), userInfo: nil, repeats: true)
    }
    func keyboardDidHide(notification:NSNotification){
        scrollingTimer.invalidate()
    }
    
    func scrollToTop(){
        mainWebView.scrollView.contentOffset = CGPointMake(0, 0)
    }
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
    }
    @IBAction func importPressed(sender: UIButton) {
        var xmlField: UITextField?
        func didPasteFile(alert: UIAlertAction!){
            importedXMLText = xmlField?.text
            let url = NSURL(string: "http://localhost:22179/snap/snap.html#open:http://localhost:22179/project.xml")
            let requestPage = NSURLRequest(URL: url!)
            mainWebView?.loadRequest(requestPage)
        }
        func addTextFieldConfigHandler(textField: UITextField!){
            textField.placeholder = "Paste your XML project text here!"
            xmlField = textField
        }
        let importPrompt = UIAlertController(title: "File Import", message: "Paste your xml project file to import it.", preferredStyle: UIAlertControllerStyle.Alert)
        importPrompt.addTextFieldWithConfigurationHandler(addTextFieldConfigHandler)
        importPrompt.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Default, handler: nil))
        importPrompt.addAction(UIAlertAction(title: "Import", style: UIAlertActionStyle.Default, handler: didPasteFile))
        presentViewController(importPrompt, animated: true, completion: nil)
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
            let copied = CNCopyCurrentNetworkInfo(ifName)
            if (copied != nil){
            let info: NSDictionary = copied.takeUnretainedValue()
                if (info["SSID"] != nil){
                    ssid = info["SSID"] as! NSString
                }
            }
        }
        return ssid as String
    }
    //end ssid
    //get ip
    // Return IP address of WiFi interface (en0) as a String, or `nil`
    func getWiFiAddress() -> String? {
        var address : String?
        
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs> = nil
        if getifaddrs(&ifaddr) == 0 {
            
            // For each interface ...
            for (var ptr = ifaddr; ptr != nil; ptr = ptr.memory.ifa_next) {
                let interface = ptr.memory
                
                // Check for IPv4 or IPv6 interface:
                let addrFamily = interface.ifa_addr.memory.sa_family
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                    
                    // Check interface name:
                    if let name = String.fromCString(interface.ifa_name) where name == "en0" {
                        
                        // Convert interface address to a human readable string:
                        var addr = interface.ifa_addr.memory
                        var hostname = [CChar](count: Int(NI_MAXHOST), repeatedValue: 0)
                        getnameinfo(&addr, socklen_t(interface.ifa_addr.memory.sa_len),
                            &hostname, socklen_t(hostname.count),
                            nil, socklen_t(0), NI_NUMERICHOST)
                        address = String.fromCString(hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return address
    }
    //end ip
    
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
            let temp = Int(round((captured[1] as NSString).floatValue))
            var intensity: UInt8
            
            let portInt = Int(captured[0].toInt()!)
            if (portInt > 4 || portInt < 1){
                return .OK(.RAW("Invalid Port (should be between 1 and 4 inclusively)"))
            }
            let port = UInt8(portInt)
            if (temp < 0){
                intensity = 0
            }
            else if (temp > 100){
                intensity = 100
            }
            else{
                intensity = UInt8(temp)
            }
            self.hbServe.setLED(port, intensity: intensity)
            NSThread.sleepForTimeInterval(self.responseTime);
            return .OK(.RAW("LED set"))
        }
        server["/hummingbird/out/triled/(.+)/(.+)/(.+)/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            var temp = Int(round((captured[1] as NSString).floatValue))
            var rValue: UInt8
            
            let portInt = Int(captured[0].toInt()!)
            if (portInt > 2 || portInt < 1){
                return .OK(.RAW("Invalid Port (should be between 1 and 4 inclusively)"))
            }
            let port = UInt8(portInt)
            
            if (temp < 0){
                rValue = 0
            }
            else if (temp > 100){
                rValue = 100
            }
            else{
                rValue = UInt8(temp)
            }
            temp = Int(round((captured[2] as NSString).floatValue))
            var gValue: UInt8
            if (temp < 0){
                gValue = 0
            }
            else if (temp > 100){
                gValue = 100
            }
            else{
                gValue = UInt8(temp)
            }
            temp = Int(round((captured[3] as NSString).floatValue))
            var bValue: UInt8
            if (temp < 0){
                bValue = 0
            }
            else if (temp > 100){
                bValue = 100
            }
            else{
                bValue = UInt8(temp)
            }
            self.hbServe.setTriLED(port, r: rValue, g: gValue, b: bValue)
            NSThread.sleepForTimeInterval(self.responseTime);
            return .OK(.RAW("Tri-LED set"))
        }
        server["/hummingbird/out/vibration/(.+)/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            let temp = Int(round((captured[1] as NSString).floatValue))
            var intensity: UInt8
            
            let portInt = Int(captured[0].toInt()!)
            if (portInt > 2 || portInt < 1){
                return .OK(.RAW("Invalid Port (should be between 1 and 4 inclusively)"))
            }
            let port = UInt8(portInt)
            
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
            NSThread.sleepForTimeInterval(self.responseTime);
            return .OK(.RAW("Vibration set"))
        }
        server["/hummingbird/out/servo/(.+)/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            let portInt = Int(captured[0].toInt()!)
            if (portInt > 4 || portInt < 1){
                return .OK(.RAW("Invalid Port (should be between 1 and 4 inclusively)"))
            }
            let port = UInt8(portInt)
            
            let temp = Int(round((captured[1] as NSString).floatValue))
            var angle: UInt8
            if (temp < 0){
                angle = 0
            }
            else if (temp > 180){
                angle = 180
            }
            else{
                angle = UInt8(temp)
            }
            
            self.hbServe.setServo(port, angle: angle)
            NSThread.sleepForTimeInterval(self.responseTime);
            return .OK(.RAW("Servo set"))
        }
        server["/hummingbird/out/motor/(.+)/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            let temp = Int(round((captured[1] as NSString).floatValue))
            var intensity: Int
            
            let portInt = Int(captured[0].toInt()!)
            if (portInt > 2 || portInt < 1){
                return .OK(.RAW("Invalid Port (should be between 1 and 4 inclusively)"))
            }
            let port = UInt8(portInt)
            
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
            NSThread.sleepForTimeInterval(self.responseTime);
            return .OK(.RAW("Motor set"))
        }
        server["/hummingbird/in/sensors"] = { request in
            var sensorData = self.hbServe.getAllSensorDataFromPoll()
            let response: String = "" + String(rawto100scale(sensorData[0])) + " " + String(rawto100scale(sensorData[1])) + " " + String(rawto100scale(sensorData[2])) + " " + String(rawto100scale(sensorData[3]))
            return .OK(.RAW(response))
        }
        server["/hummingbird/in/sensor/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            let portInt = Int(captured[0].toInt()!)
            if (portInt > 4 || portInt < 1){
                return .OK(.RAW("Invalid Port (should be between 1 and 4 inclusively)"))
            }
            let port = UInt8(portInt)
            
            let sensorData = rawto100scale(self.hbServe.getSensorDataFromPoll(port))
            let response: String = String(sensorData)
            return .OK(.RAW(response))
        }
        server["/hummingbird/in/distance/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            let portInt = Int(captured[0].toInt()!)
            if (portInt > 4 || portInt < 1){
                return .OK(.RAW("Invalid Port (should be between 1 and 4 inclusively)"))
            }
            let port = UInt8(portInt)
            
            let sensorData = rawToDistance(self.hbServe.getSensorDataFromPoll(port))
            let response: String = String(sensorData)
            return .OK(.RAW(response))
        }
        server["/hummingbird/in/sound/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            let portInt = Int(captured[0].toInt()!)
            if (portInt > 4 || portInt < 1){
                return .OK(.RAW("Invalid Port (should be between 1 and 4 inclusively)"))
            }
            let port = UInt8(portInt)
            
            let sensorData = rawToSound(self.hbServe.getSensorDataFromPoll(port))
            let response: String = String(sensorData)
            return .OK(.RAW(response))
        }
        server["/hummingbird/in/temperature/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            let portInt = Int(captured[0].toInt()!)
            if (portInt > 4 || portInt < 1){
                return .OK(.RAW("Invalid Port (should be between 1 and 4 inclusively)"))
            }
            let port = UInt8(portInt)
            
            let sensorData = rawToTemp(self.hbServe.getSensorDataFromPoll(port))
            let response: String = String(sensorData)
            return .OK(.RAW(response))
        }
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
            
            if let importText = self.importedXMLText{
                self.importedXMLText = nil
                return .OK(.RAW(importText))
                
            }
            
            let urlFromXMl = (UIApplication.sharedApplication().delegate as! AppDelegate).getFileUrl()
            var path: String
            if let tempURL = urlFromXMl{
                path = tempURL.path!
            } else {
                path = NSBundle.mainBundle().pathForResource("iPadstart", ofType: "xml")!
            }
            let rawText = String(contentsOfFile: path, encoding: NSUTF8StringEncoding, error: nil)
            
            return .OK(.RAW(rawText!))
        }
        server["/snap/(.+)"] = HttpHandlers.directoryBrowser(getSnapPath())
        server["/snap/Backgrounds/(.+)"] = HttpHandlers.directoryBrowser(getSnapPath().stringByAppendingPathComponent("Backgrounds"))
        server["/snap/Costumes/(.+)"] = HttpHandlers.directoryBrowser(getSnapPath().stringByAppendingPathComponent("Costumes"))
        server["/snap/Sounds/(.+)"] = HttpHandlers.directoryBrowser(getSnapPath().stringByAppendingPathComponent("Sounds"))
        server["/snap/Sounds"] = HttpHandlers.directoryBrowser(getSnapPath().stringByAppendingPathComponent("Sounds"))
        server["/snap/Examples/(.+)"] = HttpHandlers.directoryBrowser(getSnapPath().stringByAppendingPathComponent("Examples"))
        server["/snap/help/(.+)"] = HttpHandlers.directoryBrowser(getSnapPath().stringByAppendingPathComponent("help"))
        server["/snap/libraries/(.+)"] = HttpHandlers.directoryBrowser(getSnapPath().stringByAppendingPathComponent("libraries"))
        
    }
    func changedStatus(notification: NSNotification){
        let userinfo = notification.userInfo as! [String: Bool]
        if let isConnected: Bool = userinfo["isConnected"]{
            if isConnected{
                NSLog("device connected")
                hbServe.turnOffLightsMotor()
                NSThread.sleepForTimeInterval(0.1)
                hbServe.stopPolling()
                NSThread.sleepForTimeInterval(0.1)
                hbServe.beginPolling()
            }
            else{
                NSLog("device disconnected")

            }
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

