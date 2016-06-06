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
import SystemConfiguration
import SystemConfiguration.CaptiveNetwork
import CoreMotion
import WebKit
import MessageUI

class ViewController: UIViewController, CLLocationManagerDelegate, WKUIDelegate, MFMailComposeViewControllerDelegate, AVAudioRecorderDelegate {
    
    @IBOutlet weak var TypingText: UITextField!
    @IBOutlet weak var renameButton: UIButton!
    @IBOutlet weak var connectedIndicator: UILabel!
    @IBOutlet weak var importButton: UIButton!
    @IBOutlet weak var recordButton: UIButton!
    var last_dialog_response: String?
    let responseTime = 0.001
    var hbServes = [String:HummingbirdServices]()
    //var hbServe: HummingbirdServices!
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
    var recorder: AVAudioRecorder?
    let sharedBluetoothDiscovery = BluetoothDiscovery.getBLEDiscovery()
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    func isConnectedToInternet() -> Bool{
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(sizeofValue(zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let defaultRouteReachability = withUnsafePointer(&zeroAddress) {
            SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0))
        }
        
        var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags()
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) {
            return false
        }
        
        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        
        return isReachable && !needsConnection
    }
    /*
    func webView(webView: WKWebView, createWebViewWithConfiguration configuration: WKWebViewConfiguration, forNavigationAction navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if(navigationAction.targetFrame == nil) {
            var request: NSMutableURLRequest = navigationAction.request.mutableCopy() as! NSMutableURLRequest
            var url_str = navigationAction.request.URL!.absoluteString
            
            //print("Got NavigationAction Request of: ", url_str);
            //if (navigationAction.request.URL?.absoluteString.hasPrefix("data:") == true) {
            NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) {
                response, text, error in
                //print("MineType: ", response!.MIMEType)
                //print("Response: ", response!)
                let mailComposer = MFMailComposeViewController()
                mailComposer.mailComposeDelegate = self
                mailComposer.title = "My Snap Project"
                let mineType: String = "text/xml"
                if(error == nil && response!.MIMEType == mineType) {
                    UIPasteboard.generalPasteboard().string = NSString(data: text!, encoding: NSUTF8StringEncoding) as String?
                    mailComposer.addAttachmentData(text!, mimeType: mineType, fileName: "project.xml")
                    let prompt = UIAlertController(title: "Copied to clipboard", message: "The contents of your project file has been copied to your clipboard. Would you like to email the XML file?", preferredStyle: UIAlertControllerStyle.Alert)
                    prompt.addAction(UIAlertAction(title: "No", style: UIAlertActionStyle.Default, handler: nil))
                    func sendEmail(action: UIAlertAction!){
                        self.presentViewController(mailComposer, animated: true, completion: nil)
                    }
                    prompt.addAction(UIAlertAction(title: "Yes", style: UIAlertActionStyle.Default, handler: sendEmail))
                    self.presentViewController(prompt, animated: true, completion: nil)
                    
                }
                else {
                    print("Error: ", error)
                }
                return
            }
            //}
        }
        return nil
    }
    */
    func mailComposeController(controller: MFMailComposeViewController, didFinishWithResult result: MFMailComposeResult, error: NSError?) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }

    override func loadView() {
        super.loadView()
        TypingText.hidden = true
        mainWebView = WKWebView(frame: self.view.frame)
        mainWebView.UIDelegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.keyboardDidShow(_:)), name: UIKeyboardDidShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.keyboardDidHide(_:)), name: UIKeyboardDidHideNotification, object: nil)
        
        prepareServer()
        server.start(22179)
        navigationController!.setNavigationBarHidden(true, animated:true)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.changedStatus(_:)), name: BluetoothStatusChangedNotification, object: nil)
        
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
    
        mainWebView.contentMode = UIViewContentMode.ScaleAspectFit
        let url = NSURL(string: "http://localhost:22179/DragAndDrop/HummingbirdDragAndDrop.html")
        if(isConnectedToInternet()){
            if(shouldUpdate()){
                getUpdate()
                
            }
            if let ip = getWiFiAddress(){
                let connectionAlert = UIAlertController(title: "Connected", message: "The app is currently connecting to a local version of [PROGRAM]. If would like to use the app as a server use this IP address: " + ip + "with port: 22179", preferredStyle: UIAlertControllerStyle.Alert)
                connectionAlert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
                self.presentViewController(connectionAlert, animated: true, completion: nil)
            }
            else{
                let connectionAlert = UIAlertController(title: "Connected", message: "The app is currently connecting to a local version of [PROGRAM]. If would like to use the app as a server, you need to be connected to wifi. Either you are not connected to wifi or have some connection connection issues.", preferredStyle: UIAlertControllerStyle.Alert)
                connectionAlert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
                self.presentViewController(connectionAlert, animated: true, completion: nil)
            }
            
            let requestPage = NSURLRequest(URL: url!)
            mainWebView!.loadRequest(requestPage)
            self.view.addSubview(mainWebView)
        }
        else{
            let noConnectionAlert = UIAlertController(title: "Cannot Connect", message: "This app required an internet connection for certain features to work. There is currently no connection avaliable. If this is your first time opening the app, it will NOT load. You need to open the app while you have internet at least once so that the source code can be downloaded", preferredStyle: UIAlertControllerStyle.Alert)
            noConnectionAlert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
            self.presentViewController(noConnectionAlert, animated: true, completion: nil)
            let requestPage = NSURLRequest(URL: url!)
            mainWebView!.loadRequest(requestPage)
            self.view.addSubview(mainWebView)
        }
        //self.view.bringSubviewToFront(importButton)
        //self.view.bringSubviewToFront(recordButton)
        //self.view.bringSubviewToFront(connectedIndicator)
        //self.view.bringSubviewToFront(renameButton)
        //self.view.bringSubviewToFront(TypingText)
    }
    var scrollingTimer = NSTimer()
    func keyboardDidShow(notification:NSNotification){
        //TypingText.hidden = false
        
        scrollingTimer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: #selector(ViewController.scrollToTop), userInfo: nil, repeats: true)
    }
    func keyboardDidHide(notification:NSNotification){
        //TypingText.hidden = true
        //TypingText.text=""
        scrollingTimer.invalidate()
    }
    
    func scrollToTop(){
        mainWebView.scrollView.contentOffset = CGPointMake(0, 0)
    }
    /*
    @IBAction func renamePressed(sender: UIButton) {
            let alertController = UIAlertController(title: "Set Name", message: "Enter a name for your Hummingbird (up to 18 characters)", preferredStyle: UIAlertControllerStyle.Alert)
            let okayAction = UIAlertAction(title: "Okay", style: UIAlertActionStyle.Default){
                (action) -> Void in
                if let textField: AnyObject = alertController.textFields?.first{
                    if let name = (textField as! UITextField).text{
                            self.hbServe.setName(name)
                    }
                }
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: nil)
            alertController.addTextFieldWithConfigurationHandler{
                (txtName) -> Void in
                txtName.placeholder = "<Enter a new name>"
            }
            alertController.addAction(okayAction)
            alertController.addAction(cancelAction)
            self.presentViewController(alertController, animated: true, completion: nil)
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
    
    @IBAction func recordPressed(sender: UIButton) {
        let firstPrompt = UIAlertController(title: "Record Audio", message: "Click the record button to start recording or cancel to close this window.", preferredStyle: UIAlertControllerStyle.Alert)
        
        let recordingPrompt = UIAlertController(title: "Recording Audio", message: "Audio being recorded, click stop to stop recording", preferredStyle: UIAlertControllerStyle.Alert)
        
        let recordedPrompt = UIAlertController(title: "Save Audio", message: "Audio has been recorded, type in a name for your file and then click save to save it or cancel to delete it", preferredStyle: UIAlertControllerStyle.Alert)
        
        let savedPrompt = UIAlertController(title: "Saved!", message: "Your audio file has been saved, to access it, click the file icon in the upper left hand corner and from the dropdown menu select sounds. Another dropdown menu should appear with a list of sound files including yours. Select your file to import it into the project.", preferredStyle: UIAlertControllerStyle.Alert)
        var fileNameField: UITextField?
        let recordSettings: [String : AnyObject] = [
            AVFormatIDKey : Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey : 44100.0,
            AVNumberOfChannelsKey : 2,
            AVEncoderBitRateKey: 320000,
            AVEncoderAudioQualityKey : AVAudioQuality.High.rawValue
        ]
        let soundFolderURL = getSnapPath().URLByAppendingPathComponent("Sounds")
        let soundFileURL = soundFolderURL.URLByAppendingPathComponent("tempAudio.m4a")
        let realURL = NSURL(fileURLWithPath: soundFileURL.path!)
        var error: NSError?
        
        let audioSession = AVAudioSession.sharedInstance()
        do{
            try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
            try self.recorder = AVAudioRecorder(URL: realURL, settings: recordSettings)
            recorder?.delegate = self
            recorder?.prepareToRecord()
            recorder?.meteringEnabled = true
        } catch {
            print("Error: Failed to set up recorder\n")
        }
        func addTextFieldConfigHandler(textField: UITextField!){
            textField.placeholder = "Enter a name for your audio file"
            fileNameField = textField
        }
        func didStartRecording(alert: UIAlertAction!){
            recorder?.record()
            presentViewController(recordingPrompt, animated: true, completion: nil)
        }
        func didStopRecording(alert: UIAlertAction!){
            recorder?.stop()
            presentViewController(recordedPrompt, animated: true, completion: nil)
        }
        func cancelRecording(alert: UIAlertAction!){
            recorder?.stop()
            do{
                try NSFileManager.defaultManager().removeItemAtPath(soundFileURL.path!)
            } catch{
                print("Error: Couldn't delete temp audio file\n")
            }
        }
        func saveRecording(alert: UIAlertAction!){
            var filename = fileNameField?.text
            if let name = filename{
                if(name.characters.count <= 0){
                    filename = "untitled"
                }
            }
            filename = filename!.stringByAppendingString(".m4a")
            let newPath = soundFolderURL.URLByAppendingPathComponent(filename!)
            do{
                try NSFileManager.defaultManager().moveItemAtPath(soundFileURL.path!, toPath: newPath.path!)
                addToSoundsFile(filename!)
            } catch{
                print("Error: Failed to save audio file\n")
            }
            presentViewController(savedPrompt, animated: true, completion: nil)
        }
        recordingPrompt.addAction(UIAlertAction(title: "Stop", style: UIAlertActionStyle.Default, handler: didStopRecording))
        recordingPrompt.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Default, handler: cancelRecording))
        
        recordedPrompt.addTextFieldWithConfigurationHandler(addTextFieldConfigHandler)
        recordedPrompt.addAction(UIAlertAction(title: "Save", style: UIAlertActionStyle.Default, handler: saveRecording))
        recordedPrompt.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Default, handler: cancelRecording))
        
        firstPrompt.addAction(UIAlertAction(title: "Record", style: UIAlertActionStyle.Default, handler: didStartRecording))
        firstPrompt.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Default, handler: cancelRecording))
        
        savedPrompt.addAction(UIAlertAction(title: "Done", style: UIAlertActionStyle.Default, handler: nil))
        
        
        presentViewController(firstPrompt, animated: true, completion: nil)
    }
    */
    
    //for shake
    override func canBecomeFirstResponder() -> Bool {
        return true
    }
    override func motionEnded(motion: UIEventSubtype, withEvent event: UIEvent?) {
        if (motion == UIEventSubtype.MotionShake){
            wasShaken = true
            shakenTimer = NSTimer.scheduledTimerWithTimeInterval(NSTimeInterval(5), target: self, selector: #selector(ViewController.expireShake), userInfo: nil, repeats: false)
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
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = manager.location!.coordinate
    }
    //end location
    
    //get ssid
    func getSSIDInfo() -> String{
        var ssid:NSString = "null"
        if let ifs:NSArray = CNCopySupportedInterfaces(){
            for i in 0..<CFArrayGetCount(ifs){
                let ifName: UnsafePointer<Void> = CFArrayGetValueAtIndex(ifs, i)
                let rec = unsafeBitCast(ifName, AnyObject.self)
                let unsafeIfData = CNCopyCurrentNetworkInfo("\(rec)")
                if unsafeIfData != nil {
                    let ifData = unsafeIfData! as Dictionary!
                    ssid = ifData["SSID"] as! NSString
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
            var ptr = ifaddr
            while(ptr != nil) {
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
            ptr = ptr.memory.ifa_next
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
        server["/hummingbird/(.+)/out/led/(.+)/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            
            let name = String(captured[0])
            let portInt = Int(captured[1])
            let temp = Int(round((captured[2] as NSString).floatValue))
            var intensity: UInt8
            
            if (portInt > 4 || portInt < 1){
                return .OK(.RAW("Invalid Port (should be between 1 and 4 inclusively)"))
            }
            let port = UInt8(portInt!)
            if (temp < 0){
                intensity = 0
            }
            else if (temp > 100){
                intensity = 100
            }
            else{
                intensity = UInt8(temp)
            }
            self.hbServes[name]!.setLED(port, intensity: intensity)
            NSThread.sleepForTimeInterval(self.responseTime);
            return .OK(.RAW("LED set"))
        }
        server["/hummingbird/(.+)/out/triled/(.+)/(.+)/(.+)/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            
            let name = String(captured[0])
            let portInt = Int(captured[1])
            var temp = Int(round((captured[2] as NSString).floatValue))
            var rValue: UInt8
            
            if (portInt > 2 || portInt < 1){
                return .OK(.RAW("Invalid Port (should be between 1 and 4 inclusively)"))
            }
            let port = UInt8(portInt!)
            
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
            self.hbServes[name]!.setTriLED(port, r: rValue, g: gValue, b: bValue)
            NSThread.sleepForTimeInterval(self.responseTime);
            return .OK(.RAW("Tri-LED set"))
        }
        server["/hummingbird/(.+)/out/vibration/(.+)/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            let name = String(captured[0])
            let portInt = Int(captured[1])
            let temp = Int(round((captured[2] as NSString).floatValue))
            var intensity: UInt8
            
            
            if (portInt > 2 || portInt < 1){
                return .OK(.RAW("Invalid Port (should be between 1 and 4 inclusively)"))
            }
            let port = UInt8(portInt!)
            
            if (temp < 0){
                intensity = 0
            }
            else if (temp > 100){
                intensity = 100
            }
            else{
                intensity = UInt8(temp)
            }
            
            self.hbServes[name]!.setVibration(port, intensity: intensity)
            NSThread.sleepForTimeInterval(self.responseTime);
            return .OK(.RAW("Vibration set"))
        }
        server["/hummingbird/(.+)/out/servo/(.+)/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            let name = String(captured[0])
            let portInt = Int(captured[1])
            let temp = Int(round((captured[2] as NSString).floatValue))
            if (portInt > 4 || portInt < 1){
                return .OK(.RAW("Invalid Port (should be between 1 and 4 inclusively)"))
            }
            let port = UInt8(portInt!)
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
            
            self.hbServes[name]!.setServo(port, angle: angle)
            NSThread.sleepForTimeInterval(self.responseTime);
            return .OK(.RAW("Servo set"))
        }
        server["/hummingbird/(.+)/out/motor/(.+)/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            let name = String(captured[0])
            let portInt = Int(captured[1])
            let temp = Int(round((captured[2] as NSString).floatValue))
            var intensity: Int

            if (portInt > 2 || portInt < 1){
                return .OK(.RAW("Invalid Port (should be between 1 and 4 inclusively)"))
            }
            let port = UInt8(portInt!)
            
            if (temp < -100){
                intensity = -100
            }
            else if (temp > 100){
                intensity = 100
            }
            else{
                intensity = temp
            }
            self.hbServes[name]!.setMotor(port, speed: intensity)
            NSThread.sleepForTimeInterval(self.responseTime);
            return .OK(.RAW("Motor set"))
        }
        server["/hummingbird/(.+)/in/sensors"] = { request in
            let name = String(request.capturedUrlGroups[0])
            var sensorData = self.hbServes[name]!.getAllSensorDataFromPoll()
            let response: String = "" + String(rawto100scale(sensorData[0])) + " " + String(rawto100scale(sensorData[1])) + " " + String(rawto100scale(sensorData[2])) + " " + String(rawto100scale(sensorData[3]))
            return .OK(.RAW(response))
        }
        server["/hummingbird/(.+)/in/sensor/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            let name = String(captured[0])
            let portInt = Int(captured[1])
            if (portInt > 4 || portInt < 1){
                return .OK(.RAW("Invalid Port (should be between 1 and 4 inclusively)"))
            }
            let port = UInt8(portInt!)
            
            let sensorData = rawto100scale(self.hbServes[name]!.getSensorDataFromPoll(port))
            let response: String = String(sensorData)
            return .OK(.RAW(response))
        }
        server["/hummingbird/(.+)/in/distance/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            let name = String(captured[0])
            let portInt = Int(captured[1])
            if (portInt > 4 || portInt < 1){
                return .OK(.RAW("Invalid Port (should be between 1 and 4 inclusively)"))
            }
            let port = UInt8(portInt!)
            
            let sensorData = rawToDistance(self.hbServes[name]!.getSensorDataFromPoll(port))
            let response: String = String(sensorData)
            return .OK(.RAW(response))
        }
        server["/hummingbird/(.+)/in/sound/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            let name = String(captured[0])
            let portInt = Int(captured[1])
            if (portInt > 4 || portInt < 1){
                return .OK(.RAW("Invalid Port (should be between 1 and 4 inclusively)"))
            }
            let port = UInt8(portInt!)
            
            let sensorData = rawToSound(self.hbServes[name]!.getSensorDataFromPoll(port))
            let response: String = String(sensorData)
            return .OK(.RAW(response))
        }
        server["/hummingbird/(.+)/in/temperature/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            let name = String(captured[0])
            let portInt = Int(captured[1])
            if (portInt > 4 || portInt < 1){
                return .OK(.RAW("Invalid Port (should be between 1 and 4 inclusively)"))
            }
            let port = UInt8(portInt!)
            
            let sensorData = rawToTemp(self.hbServes[name]!.getSensorDataFromPoll(port))
            let response: String = String(sensorData)
            return .OK(.RAW(response))
        }
        server["/hummingbird/(.+)/status"] = { request in
            let name = String(request.capturedUrlGroups[0])
            let response = (self.hbServes[name] != nil) ? 1 : 0
            return .OK(.RAW(String(response)))
        }
        server["/hummingbird/(.+)/rename/(.+)"] = { request in
            let nameFrom = request.capturedUrlGroups[0]
            let nameTo = request.capturedUrlGroups[1]
            let hbServe = self.hbServes[nameFrom]!
            self.hbServes.removeValueForKey(nameFrom)
            hbServe.setName(nameTo)
            self.hbServes[nameTo] = hbServe
            return .OK(.RAW("Renamed"))
        }
        server["/hummingbird/names"] = { request in
            let names = Array(self.hbServes.keys.lazy).joinWithSeparator("\n")
            return .OK(.RAW(names))
        }
        server["/hummingbird/(.+)/disconnect"] = { request in
            let name = request.capturedUrlGroups[0]
            self.hbServes[name]!.disconnectFromDevice()
            return .OK(.RAW("Disconnected"))
        }
        server["/hummingbird/discover"] = { request in
            let dict = self.sharedBluetoothDiscovery.getDiscovered()
            let strings = Array(dict.keys.lazy)
            return .OK(.RAW(strings.joinWithSeparator("\n")))
        }
        server["/hummingbird/(.+)/connect"] = { request in
            let name = request.capturedUrlGroups[0]
            let peripheral = self.sharedBluetoothDiscovery.getDiscovered()[name]!
            let hbServe = HummingbirdServices()
            self.sharedBluetoothDiscovery.connectToPeripheral(peripheral, name: name)
            hbServe.attachToDevice(name)
            self.hbServes[name] = hbServe
            return .OK(.RAW("Connected!"))
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
        server["/iPad/dialog/(.+)/(.+)"] = {request in
            self.last_dialog_response = nil
            let captured = request.capturedUrlGroups
            let title = String(captured[0])
            let question = String(captured[1])
            let alertController = UIAlertController(title: title, message: question, preferredStyle: UIAlertControllerStyle.Alert)
            let okayAction = UIAlertAction(title: "Okay", style: UIAlertActionStyle.Default){
                (action) -> Void in
                if let textField: AnyObject = alertController.textFields?.first{
                    if let response = (textField as! UITextField).text{
                        self.last_dialog_response = response;
                    }
                }
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel){
                (action) -> Void in
                    self.last_dialog_response = ""
            }
            alertController.addTextFieldWithConfigurationHandler{
                (txtName) -> Void in
                txtName.placeholder = "<Response>"
            }
            alertController.addAction(okayAction)
            alertController.addAction(cancelAction)
            dispatch_async(dispatch_get_main_queue()){
                self.presentViewController(alertController, animated: true, completion: nil)
            }
            return .OK(.RAW("Dialog Presented"))
        }
        server["/iPad/dialog_response"] = {request in
            if let response = self.last_dialog_response {
                if (response == "") {
                    return .OK(.RAW("Cancelled"))
                } else {
                    return .OK(.RAW("\'" + response + "\'"))
                }
            }
            else {
                return .OK(.RAW("No Response"))
            }
            
        }
        /*server["/project.xml"] = {request in
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
            do{
                let rawText = try String(contentsOfFile: path, encoding: NSUTF8StringEncoding)
                return .OK(.RAW(rawText))
            } catch {
                print("Error: Couldn't get contents of XML file\n")
                let rawText = ""
                return .OK(.RAW(rawText))
            }
        }*/
        server["/DragAndDrop/(.+)"] = HttpHandlers.directoryBrowser(getPath().path!)
        server["/DragAndDrop/Block/(.+)"] = HttpHandlers.directoryBrowser(getPath().URLByAppendingPathComponent("Block").path!)
        server["/DragAndDrop/BlockContainers/(.+)"] = HttpHandlers.directoryBrowser(getPath().URLByAppendingPathComponent("BlockContainers").path!)
        server["/DragAndDrop/BlockDefsAndList/(.+)"] = HttpHandlers.directoryBrowser(getPath().URLByAppendingPathComponent("BlockDefsAndList").path!)
        server["/DragAndDrop/BlockParts/(.+)"] = HttpHandlers.directoryBrowser(getPath().URLByAppendingPathComponent("BlockParts").path!)
        server["/DragAndDrop/ColorsAndGraphics/(.+)"] = HttpHandlers.directoryBrowser(getPath().URLByAppendingPathComponent("ColorsAndGraphics").path!)
        server["/DragAndDrop/Data/(.+)"] = HttpHandlers.directoryBrowser(getPath().URLByAppendingPathComponent("Data").path!)
        server["/DragAndDrop/SVGIcons/(.+)"] = HttpHandlers.directoryBrowser(getPath().URLByAppendingPathComponent("SVGIcons").path!)
        server["/DragAndDrop/UIParts/(.+)"] = HttpHandlers.directoryBrowser(getPath().URLByAppendingPathComponent("UIParts").path!)
    }
    func changedStatus(notification: NSNotification){
        let userinfo = notification.userInfo as! [String: AnyObject]
        if let name: String = userinfo["name"] as? String {
            if let isConnected: Bool = userinfo["isConnected"] as? Bool{
                if isConnected{
                    NSLog("device connected")
                    hbServes[name]!.turnOffLightsMotor()
                    NSThread.sleepForTimeInterval(0.1)
                    hbServes[name]!.stopPolling()
                    NSThread.sleepForTimeInterval(0.1)
                    hbServes[name]!.beginPolling()
                    dispatch_async(dispatch_get_main_queue()){
                    self.connectedIndicator.textColor = UIColor.greenColor()
                    }
                }
            }
            else{
                NSLog("device disconnected")
                dispatch_async(dispatch_get_main_queue()){
                    self.connectedIndicator.textColor = UIColor.redColor()
                    self.hbServes.removeValueForKey(name)
                }
            }
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

