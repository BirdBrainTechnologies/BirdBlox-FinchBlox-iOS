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

class ViewController: UIViewController, CLLocationManagerDelegate, WKUIDelegate, MFMailComposeViewControllerDelegate, AVAudioRecorderDelegate, WKNavigationDelegate {
    
    @IBOutlet weak var TypingText: UITextField!
    @IBOutlet weak var renameButton: UIButton!
    @IBOutlet weak var connectedIndicator: UILabel!
    @IBOutlet weak var importButton: UIButton!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var loadingView: UIView!
    var last_dialog_response: String?
    var last_choice_response = 0
    let responseTime = 0.001
    var hbServes = [String:HummingbirdServices]()
    //var hbServe: HummingbirdServices!
    let server: HttpServer = HttpServer()
    var wasShaken: Bool = false
    var shakenTimer: NSTimer = NSTimer()
    var pingTimer: NSTimer = NSTimer()
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
    
    var currentFileName: String?
    var tempNew = false
    
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
    
    func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
        NSLog(navigation.description)
    }
    func webView(webView: WKWebView, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
        decisionHandler(WKNavigationActionPolicy.Allow)
    }
    
    func webView(webView: WKWebView, createWebViewWithConfiguration configuration: WKWebViewConfiguration, forNavigationAction navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let url_str = navigationAction.request.URL!.absoluteString
        print("Got NavigationAction Request of: ", url_str);
        if(navigationAction.targetFrame == nil) {
            let request: NSMutableURLRequest = navigationAction.request.mutableCopy() as! NSMutableURLRequest
            //if (navigationAction.request.URL?.absoluteString.hasPrefix("data:") == true) {
            NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) {
                response, text, error in
                
                if (error == nil && response!.MIMEType == "text/xml") {
                    let xml = NSString(data: text!, encoding: NSUTF8StringEncoding)!
                    if let filename = self.currentFileName  {
                        if(self.tempNew == false) {
                            saveStringToFile(xml, fileName: filename)
                            return
                        }
                    }
                    let alertController = UIAlertController(title: "Save", message: "Enter a name for your file", preferredStyle: UIAlertControllerStyle.Alert)
                    let okayAction = UIAlertAction(title: "Okay", style: UIAlertActionStyle.Default){
                        (action) -> Void in
                        if let textField: AnyObject = alertController.textFields?.first{
                            if let response = (textField as! UITextField).text{
                                self.currentFileName = response.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
                                
                                let allFiles = getSavedFileNames()
                                //If we are about to overwrite a file
                                if(allFiles.contains(self.currentFileName!)) {
                                    NSLog("File exists, asking for confirmation")
                                    let newAlertController = UIAlertController(title: "Save", message: "This filename is already in use, do you want to overwrite the existing file?", preferredStyle: UIAlertControllerStyle.Alert)
                                    let yesAction = UIAlertAction(title: "Yes", style: UIAlertActionStyle.Default) {
                                        (action) -> Void in
                                        saveStringToFile(xml, fileName: self.currentFileName!)
                                    }
                                    let noAction = UIAlertAction(title: "No", style: UIAlertActionStyle.Default) {
                                        (action) -> Void in
                                        self.currentFileName = nil
                                        self.presentViewController(alertController, animated: true, completion: nil)
                                    }
                                    newAlertController.addAction(yesAction)
                                    newAlertController.addAction(noAction)
                                    NSLog("Going to present confirmation dialog")
                                    self.presentViewController(newAlertController, animated: true, completion: nil)
                                } else {
                                    NSLog("Saving string to file")
                                    saveStringToFile(xml, fileName: self.currentFileName!)
                                    return
                                }
                            }
                        }
                    }
                    let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel) {
                        (action) -> Void in
                        self.tempNew = false
                        return
                    }
                    alertController.addTextFieldWithConfigurationHandler{
                        (textField) -> Void in
                        textField.becomeFirstResponder()
                        textField.placeholder = "<Filename>"
                    }
                    alertController.addAction(okayAction)
                    alertController.addAction(cancelAction)
                    
                    dispatch_async(dispatch_get_main_queue()){
                        NSLog("Start Present")
                        //self.presentViewController(UIAlertController(title: "TEST", message: "abc", preferredStyle: UIAlertControllerStyle.Alert), animated: true) {
                        self.presentViewController(alertController, animated: true) {
                            NSLog("End Present")
                        }
                    }
                }
                return
            }
        }
        return nil
    }

    func mailComposeController(controller: MFMailComposeViewController, didFinishWithResult result: MFMailComposeResult, error: NSError?) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func checkServer() {
        //print("Pinging")
        let url = NSURL(string: "http://localhost:22179/server/ping")
        let task = NSURLSession.sharedSession().dataTaskWithURL(url!) {(data, response, error) in
            if ((error) != nil){
                print("Ping failed")
                self.server.stop()
                self.prepareServer()
                self.server.start(22179)
                return
            }
        }
        task.resume()
    }
    
    override func loadView() {
        super.loadView()
        TypingText.hidden = true
        mainWebView = WKWebView(frame: self.view.frame)
        mainWebView.UIDelegate = self
        mainWebView.navigationDelegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.keyboardDidShow(_:)), name: UIKeyboardDidShowNotification, object: nil)
//        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.keyboardDidHide(_:)), name: UIKeyboardDidHideNotification, object: nil)
        
        prepareServer()
        server.start(22179)
        navigationController!.setNavigationBarHidden(true, animated:true)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.changedStatus(_:)), name: BluetoothStatusChangedNotification, object: nil)
        
        pingTimer = NSTimer.scheduledTimerWithTimeInterval(NSTimeInterval(5), target: self, selector: #selector(ViewController.checkServer), userInfo: nil, repeats: true)
        checkServer()
        
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
                let connectionAlert = UIAlertController(title: "Connected", message: "The app is currently connecting to a local version of BirdBlox. If would like to use the app as a server use this IP address: " + ip + " with port: 22179", preferredStyle: UIAlertControllerStyle.Alert)
                connectionAlert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
                self.presentViewController(connectionAlert, animated: true, completion: nil)
            }
            else{
                let connectionAlert = UIAlertController(title: "Connected", message: "The app is currently connecting to a local version of BirdBlox. If would like to use the app as a server, you need to be connected to wifi. Either you are not connected to wifi or have some connection connection issues.", preferredStyle: UIAlertControllerStyle.Alert)
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
    //var scrollingTimer = NSTimer()
    //func keyboardDidShow(notification:NSNotification){
    //    //TypingText.hidden = false
    //
    //    scrollingTimer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: #selector(ViewController.scrollToTop), userInfo: nil, repeats: true)
    //}
    //func keyboardDidHide(notification:NSNotification){
    //    //TypingText.hidden = true
    //    //TypingText.text=""
    //    scrollingTimer.invalidate()
    //}
    
    //func scrollToTop(){
    //    mainWebView.scrollView.contentOffset = CGPointMake(0, 0)
    //}
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
    
    func handleBadRequest(name: String) {
        NSLog("Attempted to send command to invalid device: " + name)
        NSLog("Devices found in disovery" + self.sharedBluetoothDiscovery.getDiscovered().keys.joinWithSeparator(", "))
        self.sharedBluetoothDiscovery.startScan()
    }
    //end orientation
    deinit{
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BluetoothStatusChangedNotification, object: nil)
    }
    func prepareServer(){
        server["/hummingbird/(.+)/out/led/(.+)/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            
            let name = String(captured[0])
            if(self.hbServes.keys.contains(name) == false) {
                self.handleBadRequest(name) 
                return .OK(.RAW("Not connected!"))
            }
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
        server["/hummingbird/(.+)/out/stop"] = { request in
            let captured = request.capturedUrlGroups
            
            let name = String(captured[0])
            if(self.hbServes.keys.contains(name) == false) {
                self.handleBadRequest(name)
                return .OK(.RAW("Not connected!"))
            }
            self.hbServes[name]!.setLED(1, intensity: 0)
            self.hbServes[name]!.setLED(2, intensity: 0)
            self.hbServes[name]!.setLED(3, intensity: 0)
            self.hbServes[name]!.setLED(4, intensity: 0)
            self.hbServes[name]!.setTriLED(1, r: 0, g: 0, b: 0)
            self.hbServes[name]!.setTriLED(2, r: 0, g: 0, b: 0)
            self.hbServes[name]!.setMotor(1, speed: 0)
            self.hbServes[name]!.setMotor(2, speed: 0)
            self.hbServes[name]!.setVibration(1, intensity: 0)
            self.hbServes[name]!.setVibration(2, intensity: 0)
            NSThread.sleepForTimeInterval(self.responseTime);
            return .OK(.RAW("Turned off outputs"))
        }
        
        server["/hummingbird/out/stopAll"] = { request in
        let names = Array(self.hbServes.keys.lazy)
            for name in names {
                self.hbServes[name]!.setLED(1, intensity: 0)
                self.hbServes[name]!.setLED(2, intensity: 0)
                self.hbServes[name]!.setLED(3, intensity: 0)
                self.hbServes[name]!.setLED(4, intensity: 0)
                self.hbServes[name]!.setTriLED(1, r: 0, g: 0, b: 0)
                self.hbServes[name]!.setTriLED(2, r: 0, g: 0, b: 0)
                self.hbServes[name]!.setMotor(1, speed: 0)
                self.hbServes[name]!.setMotor(2, speed: 0)
                self.hbServes[name]!.setVibration(1, intensity: 0)
                self.hbServes[name]!.setVibration(2, intensity: 0)
            }
            return .OK(.RAW("Turned off all outputs for all Hummingbirds"))
        }
        server["/hummingbird/(.+)/out/triled/(.+)/(.+)/(.+)/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            
            let name = String(captured[0])
            if(self.hbServes.keys.contains(name) == false) {
                self.handleBadRequest(name)
                return .OK(.RAW("Not connected!"))
            }
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
            temp = Int(round((captured[3] as NSString).floatValue))
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
            temp = Int(round((captured[4] as NSString).floatValue))
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
            if(self.hbServes.keys.contains(name) == false) {
                self.handleBadRequest(name)
                return .OK(.RAW("Not connected!"))
            }
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
            if(self.hbServes.keys.contains(name) == false) {
                self.handleBadRequest(name)
                return .OK(.RAW("Not connected!"))
            }
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
            if(self.hbServes.keys.contains(name) == false) {
                self.handleBadRequest(name)
                return .OK(.RAW("Not connected!"))
            }
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
            if(self.hbServes.keys.contains(name) == false) {
                self.handleBadRequest(name)
                return .OK(.RAW("Not connected!"))
            }
            var sensorData = self.hbServes[name]!.getAllSensorDataFromPoll()
            let response: String = "" + String(rawto100scale(sensorData[0])) + " " + String(rawto100scale(sensorData[1])) + " " + String(rawto100scale(sensorData[2])) + " " + String(rawto100scale(sensorData[3]))
            return .OK(.RAW(response))
        }
        server["/hummingbird/(.+)/in/sensor/(.+)"] = { request in
            let captured = request.capturedUrlGroups
            let name = String(captured[0])
            if(self.hbServes.keys.contains(name) == false) {
                self.handleBadRequest(name)
                return .OK(.RAW("Not connected!"))
            }
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
            if(self.hbServes.keys.contains(name) == false) {
                self.handleBadRequest(name)
                return .OK(.RAW("Not connected!"))
            }
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
            if(self.hbServes.keys.contains(name) == false) {
                self.handleBadRequest(name)
                return .OK(.RAW("Not connected!"))
            }
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
            if(self.hbServes.keys.contains(name) == false) {
                self.handleBadRequest(name)
                return .OK(.RAW("Not connected!"))
            }
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
            if(self.hbServes.keys.contains(nameFrom) == false) {
                self.handleBadRequest(nameFrom)
                return .OK(.RAW("Not connected!"))
            }
            let nameTo = request.capturedUrlGroups[1]
            if self.hbServes[nameFrom] != nil {
                if let newName = self.hbServes[nameFrom]!.renameDevice(nameTo) {
                    self.hbServes[newName] = self.hbServes.removeValueForKey(nameFrom)
                    self.hbServes[newName]!.setName(newName)
                    NSLog("number of items in HBSERVE: " + String(self.hbServes.count))
                    return .OK(.RAW("Renamed"))
                }
            }
            return .OK(.RAW("Name not found!"))
        }
        server["/hummingbird/names"] = { request in
            let names = Array(self.hbServes.keys.lazy).joinWithSeparator("\n")
            return .OK(.RAW(names))
        }
        server["/hummingbird/connectedNames"] = {request in
            let names = self.sharedBluetoothDiscovery.getConnected().joinWithSeparator("\n")
            return .OK(.RAW(names))
        }
        server["/hummingbird/serviceNames"] = {request in
            let names = self.sharedBluetoothDiscovery.getServiceNames().joinWithSeparator("\n")
            return .OK(.RAW(names))
        }
        server["/hummingbird/ALLNames"] = {request in
            let names = self.sharedBluetoothDiscovery.getAllNames().joinWithSeparator("\n")
            return .OK(.RAW(names))
        }
        server["/hummingbird/(.+)/disconnect"] = { request in
            let name = request.capturedUrlGroups[0]
            if(self.hbServes.keys.contains(name) == false) {
                self.handleBadRequest(name)
                self.sharedBluetoothDiscovery.removeConnected(name)
                return .OK(.RAW("Not connected!"))
            }
            self.hbServes[name]!.disconnectFromDevice()
            if (self.hbServes.keys.contains(name)) {
                self.hbServes.removeValueForKey(name)
            }
            return .OK(.RAW("Disconnected"))
        }
        server["/hummingbird/discover"] = { request in
            self.sharedBluetoothDiscovery.startScan()
            let dict = self.sharedBluetoothDiscovery.getDiscovered()
            let strings = Array(dict.keys.lazy)
            return .OK(.RAW(strings.joinWithSeparator("\n")))
        }
        server["/hummingbird/ForceDiscover"] = { request in
            print("CALLED FORCE!")
            self.sharedBluetoothDiscovery.restartScan()
            let dict = self.sharedBluetoothDiscovery.getDiscovered()
            let strings = Array(dict.keys.lazy)
            return .OK(.RAW(strings.joinWithSeparator("\n")))
        }
        server["/hummingbird/totalStatus"] = { request in
            let connectedCount = self.sharedBluetoothDiscovery.getConnected().count
            let hbServeCount = self.hbServes.count
            if (connectedCount == 0) {
                return .OK(.RAW("2"))
            }
            if (connectedCount == hbServeCount) {
                return .OK(.RAW("1"))
            } else {
                
                return .OK(.RAW("0"))
            }
        }
        server["/hummingbird/(.+)/connect"] = { request in
            let name = request.capturedUrlGroups[0]
            if let peripheral = self.sharedBluetoothDiscovery.getDiscovered()[name] {
                let hbServe = HummingbirdServices()
                self.hbServes[name] = hbServe
                self.hbServes[name]!.attachToDevice(name)
                self.sharedBluetoothDiscovery.connectToPeripheral(peripheral, name: name)
                return .OK(.RAW("Connected!"))
            } else {
                return .OK(.RAW("Device not found"))
            }
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
        server["/iPad/choice/(.+)/(.+)/(.+)/(.+)"] = { request in
            self.last_choice_response = 0
            let captured = request.capturedUrlGroups
            let title = String(captured[0])
            let question = String(captured[1])
            let button1Text = String(captured[2])
            let button2Text = String(captured[3])
            let alertController = UIAlertController(title: title, message: question, preferredStyle: UIAlertControllerStyle.Alert)
            let button1Action = UIAlertAction(title: button1Text, style: UIAlertActionStyle.Default){
                (action) -> Void in
                self.last_choice_response = 1
            }
            let button2Action = UIAlertAction(title: button2Text, style: UIAlertActionStyle.Default){
                (action) -> Void in
                self.last_choice_response = 2
            }
            alertController.addAction(button1Action)
            alertController.addAction(button2Action)
            dispatch_async(dispatch_get_main_queue()){
                self.presentViewController(alertController, animated: true, completion: nil)
                
            }
            return .OK(.RAW("Choice Dialog Presented"))

        }
        server["iPad/choice_response"] = {request in
            return .OK(.RAW(String(self.last_choice_response)))
        }
        server["/iPad/dialog/(.+)/(.+)/(.+)"] = {request in
            self.last_dialog_response = nil
            let captured = request.capturedUrlGroups
            let title = String(captured[0])
            let question = String(captured[1])
            let answerHolder = String(captured[2])
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
                    self.last_dialog_response = "!~<!--CANCELLED-->~!"
            }
            alertController.addTextFieldWithConfigurationHandler{
                (txtName) -> Void in
                txtName.placeholder = answerHolder
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
                if (response == "!~<!--CANCELLED-->~!") {
                    return .OK(.RAW("Cancelled"))
                } else {
                    return .OK(.RAW("\'" + response + "\'"))
                }
            }
            else {
                return .OK(.RAW("No Response"))
            }
            
        }
        server["/data/files"] = {request in
            let fileList = getSavedFileNames()
            var files: String = "";
            fileList.forEach({ (string) in
                files.appendContentsOf(string)
                files.appendContentsOf("\n")
            })
            return .OK(.RAW(files))
        }
        server["/data/filename"] = {request in
            if let filename = self.currentFileName {
                return .OK(.RAW(filename))
            } else {
                return .OK(.RAW("File has no name."))
            }
        }
        server["/data/load/(.+)"] = {request in
            let filename = String(request.capturedUrlGroups[0])
            let fileContent = getSavedFileByName(filename)
            if (fileContent == "File not found") {
                return .OK(.RAW("File Not Found"))
            }
            self.currentFileName = filename.stringByReplacingOccurrencesOfString(".xml", withString: "")
            return .OK(.RAW(fileContent as (String)))
        }
        server["/data/save/(.+)"] = {request in
            NSLog("GOT SAVE")
            let filename = String(request.capturedUrlGroups[0])
            if let requestBody = request.body {
            let xml: String = requestBody.stringByReplacingOccurrencesOfString("data=", withString: "")
            print(xml)
            saveStringToFile(xml, fileName: filename)
            self.currentFileName = filename
            return .OK(.RAW("Saved"))
            } else {
                NSLog("Bodyless")
                return .OK(.RAW("darn"))
            }
        }
        server["/data/delete/(.+)"] = {request in
            let filename = String(request.capturedUrlGroups[0])
            let result = deleteFile(filename)
            if (result == false) {
                return .OK(.RAW("File Not Found"))
            }
            if (self.currentFileName == filename) {
                self.currentFileName = nil
            }
            return .OK(.RAW("File Deleted"))
        }
        server["/data/rename/(.+)/(.+)"] = {request in
            let captured = request.capturedUrlGroups
            let filename = String(captured[0])
            let newFilename = String(captured[1])
            
            let result = renameFile(filename, newFileName: newFilename)
            if (result == false) {
                return .OK(.RAW("File Not Found"))
            }
            if (self.currentFileName == filename) {
                self.currentFileName = newFilename
            }
            return .OK(.RAW("File Renamed"))
        }
        server["/data/new"] = {request in
            self.currentFileName = nil
            return .OK(.RAW("Filename reset"))
        }
        server["/data/saveAsNew"] = {request in
            self.tempNew = true
            return .OK(.RAW("Filename temporarily cleared"))
        }
        
        server["/data/autosave"] = {request in
            if let requestBody = request.body {
                let xml: String = requestBody.stringByReplacingOccurrencesOfString("data=", withString: "")
                autosave(xml)
                return .OK(.RAW("Saved"))
            } else {
                return .OK(.RAW("darn"))
            }
        }
        server["/data/loadAutosave"] = {request in
            let fileContent = getSavedFileByName("autosaveFile")
            if (fileContent == "File not found") {
                return .OK(.RAW("File Not Found"))
            }
            self.currentFileName = "autosaveFile"
            return .OK(.RAW(fileContent as (String)))
        }
        
        
        server["/server/ping"] = {request in
            return .OK(.RAW("pong"))
        }
        server["/iPad/screenSize"] = {request in
            let screenSize: CGRect = UIScreen.mainScreen().bounds
            let width = String(screenSize.width)
            let height = String(screenSize.height)
            return .OK(.RAW(height + "\n" + width))
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
        server["/settings/get/(.+)"] = {request in
            let key = request.capturedUrlGroups[0]
            let value = getSetting(key)
            if let nullCheckedValue = value {
                return .OK(.RAW(nullCheckedValue))
            } else {
                return .OK(.RAW("Default"))
            }
        }
        server["/settings/set/(.+)/(.+)"] = {request in
            let captured = request.capturedUrlGroups
            let key = captured[0]
            let value = captured[1]
            addSetting(key, value: value)
            return .OK(.RAW("Setting saved"))
        }
        server["settings/delete/key/(.+)"] = {request in
            let key = request.capturedUrlGroups[0]
            removeSetting(key)
            return .OK(.RAW("Setting Deleted"))
        }
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
        NSLog("View controller got notification: " + notification.name)
        if let name: String = userinfo["name"] as? String {
            NSLog("Got name " + name)
            if let isConnected: Bool = userinfo["isConnected"] as? Bool{
                NSLog("Got connection status")
                if isConnected{
                    NSLog("device connected")
                    if(hbServes[name] == nil) {
                        let hbServe = HummingbirdServices()
                        self.hbServes[name] = hbServe
                        self.hbServes[name]!.attachToDevice(name)
                    }
                    hbServes[name]!.turnOffLightsMotor()
                    NSThread.sleepForTimeInterval(0.1)
                    hbServes[name]!.stopPolling()
                    NSThread.sleepForTimeInterval(0.1)
                    hbServes[name]!.beginPolling()
                    dispatch_async(dispatch_get_main_queue()){
                        self.connectedIndicator.textColor = UIColor.greenColor()
                    }
                }
                else{
                    NSLog("device disconnected")
                    dispatch_async(dispatch_get_main_queue()){
                        self.connectedIndicator.textColor = UIColor.redColor()
                        if (self.hbServes.keys.contains(name)) {
                            self.hbServes.removeValueForKey(name)
                        }
                        self.sharedBluetoothDiscovery.restartScan()
                        
                    }
                }
            }
            
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

