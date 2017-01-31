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


// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


class ViewController: UIViewController, CLLocationManagerDelegate, WKUIDelegate, MFMailComposeViewControllerDelegate, AVAudioRecorderDelegate, WKNavigationDelegate {
    
    @IBOutlet weak var loadingView: UIView!
    var last_dialog_response: String?
    var last_choice_response = 0
    let responseTime = 0.001
    var hbServes = [String:HummingbirdServices]()
    //var hbServe: HummingbirdServices!
    let server: HttpServer = HttpServer()
    var wasShaken: Bool = false
    var shakenTimer: Timer = Timer()
    var pingTimer: Timer = Timer()
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
    let audioManager = AudioManager()
    var currentFileName: String?
    var tempNew = false
    
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    func isConnectedToInternet() -> Bool{
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }
        
        var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags()
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) {
            return false
        }
        
        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        
        return isReachable && !needsConnection
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NSLog(navigation.description)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(WKNavigationActionPolicy.allow)
    }
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let url_str = navigationAction.request.url!.absoluteString
        print("Got NavigationAction Request of: ", url_str);
        if(navigationAction.targetFrame == nil) {
            let request: NSMutableURLRequest = (navigationAction.request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
            //if (navigationAction.request.URL?.absoluteString.hasPrefix("data:") == true) {
            NSURLConnection.sendAsynchronousRequest(request as URLRequest, queue: OperationQueue.main) {
                response, text, error in
                
                if (error == nil && response!.mimeType == "text/xml") {
                    let xml = NSString(data: text!, encoding: String.Encoding.utf8.rawValue)!
                    if let filename = self.currentFileName  {
                        if(self.tempNew == false) {
                            saveStringToFile(xml, fileName: filename)
                            return
                        }
                    }
                    let alertController = UIAlertController(title: "Save", message: "Enter a name for your file", preferredStyle: UIAlertControllerStyle.alert)
                    let okayAction = UIAlertAction(title: "Okay", style: UIAlertActionStyle.default){
                        (action) -> Void in
                        if let textField: AnyObject = alertController.textFields?.first{
                            if let response = (textField as! UITextField).text{
                                self.currentFileName = response.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                                
                                let allFiles = getSavedFileNames()
                                //If we are about to overwrite a file
                                if(allFiles.contains(self.currentFileName!)) {
                                    NSLog("File exists, asking for confirmation")
                                    let newAlertController = UIAlertController(title: "Save", message: "This filename is already in use, do you want to overwrite the existing file?", preferredStyle: UIAlertControllerStyle.alert)
                                    let yesAction = UIAlertAction(title: "Yes", style: UIAlertActionStyle.default) {
                                        (action) -> Void in
                                        saveStringToFile(xml, fileName: self.currentFileName!)
                                    }
                                    let noAction = UIAlertAction(title: "No", style: UIAlertActionStyle.default) {
                                        (action) -> Void in
                                        self.currentFileName = nil
                                        self.present(alertController, animated: true, completion: nil)
                                    }
                                    newAlertController.addAction(yesAction)
                                    newAlertController.addAction(noAction)
                                    NSLog("Going to present confirmation dialog")
                                    self.present(newAlertController, animated: true, completion: nil)
                                } else {
                                    NSLog("Saving string to file")
                                    saveStringToFile(xml, fileName: self.currentFileName!)
                                    return
                                }
                            }
                        }
                    }
                    let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) {
                        (action) -> Void in
                        self.tempNew = false
                        return
                    }
                    alertController.addTextField{
                        (textField) -> Void in
                        textField.becomeFirstResponder()
                        textField.placeholder = "<Filename>"
                    }
                    alertController.addAction(okayAction)
                    alertController.addAction(cancelAction)
                    
                    DispatchQueue.main.async{
                        NSLog("Start Present")
                        //self.presentViewController(UIAlertController(title: "TEST", message: "abc", preferredStyle: UIAlertControllerStyle.Alert), animated: true) {
                        self.present(alertController, animated: true) {
                            NSLog("End Present")
                        }
                    }
                }
                return
            }
        }
        return nil
    }

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func checkServer() {
        //print("Pinging")
        let url = URL(string: "http://localhost:22179/server/ping")
        let task = URLSession.shared.dataTask(with: url!, completionHandler: {(data, response, error) in
            if ((error) != nil){
                print("Ping failed")
                self.server.stop()
                self.prepareServer()
                do {
                    try self.server.start(22179)
                } catch {
                    return
                }
                return
            }
        }) 
        task.resume()
    }
    
    override func loadView() {
        super.loadView()
        //TypingText.hidden = true
        mainWebView = WKWebView(frame: self.view.frame)
        mainWebView.uiDelegate = self
        mainWebView.navigationDelegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.keyboardDidShow(_:)), name: UIKeyboardDidShowNotification, object: nil)
//        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.keyboardDidHide(_:)), name: UIKeyboardDidHideNotification, object: nil)
        
        prepareServer()
        do {
            try self.server.start(22179)
        } catch {
            NSLog("Failed to Load Server")
            loadView()
            return
        }
        NSLog("Loaded Server")
        if let navCon = navigationController {
            navCon.setNavigationBarHidden(true, animated:true)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.changedStatus(_:)), name: NSNotification.Name(rawValue: BluetoothStatusChangedNotification), object: nil)
        
        pingTimer = Timer.scheduledTimer(timeInterval: TimeInterval(5), target: self, selector: #selector(ViewController.checkServer), userInfo: nil, repeats: true)
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
            altimeter.startRelativeAltitudeUpdates(to: OperationQueue.main, withHandler: {data, error in
                if(error == nil) {
                    self.currentAltitude = Float(data!.relativeAltitude)
                    self.currentPressure = Float(data!.pressure)
                }
            })
        }
        let queue = OperationQueue()
        self.motionManager.accelerometerUpdateInterval = 0.5
        if(self.motionManager.isAccelerometerAvailable) {
            self.motionManager.startAccelerometerUpdates(to: queue, withHandler: {data, error in
                DispatchQueue.main.async(execute: {
                    self.x = data!.acceleration.x
                    self.y = data!.acceleration.y
                    self.z = data!.acceleration.z
                })
            })

        }
        mainWebView.contentMode = UIViewContentMode.scaleAspectFit
        let url = URL(string: "http://localhost:22179/DragAndDrop/HummingbirdDragAndDrop.html")
        if(isConnectedToInternet()){
            let requestPage = URLRequest(url: url!)
            mainWebView!.load(requestPage)
            self.view.addSubview(mainWebView)
 
        }
        else{
            //let noConnectionAlert = UIAlertController(title: "Cannot Connect", message: "This app required an internet connection for certain features to work. There is currently no connection avaliable.", preferredStyle: UIAlertControllerStyle.alert)
            //noConnectionAlert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.default, handler: nil))
            //DispatchQueue.main.async{
            //    self.present(noConnectionAlert, animated: true, completion: nil)
            //}
            let requestPage = URLRequest(url: url!)
            mainWebView!.load(requestPage)
            self.view.addSubview(mainWebView)
        }
        let urlFromXMl = (UIApplication.shared.delegate as! AppDelegate).getFileUrl()
        var path: String
        if let tempURL = urlFromXMl{
            path = tempURL.path
            do{
                let rawText = try String(contentsOfFile: path, encoding: String.Encoding.utf8)
                let filename = (path as NSString).lastPathComponent.replacingOccurrences(of: ".bbx", with: "")
                //saveStringToFile(rawText, fileName: filename)
                
                DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async{
                    while(self.mainWebView.isLoading){
                        sched_yield()
                    };
                    print("Calling JS")
                    self.mainWebView.evaluateJavaScript("SaveManager.import( '"+filename+"' , '"+rawText+"')", completionHandler: nil)
                    deleteFileAtPath(path)
                }
            } catch {
                print("Error: Couldn't get contents of XML file\n")
            }
        }
        //self.view.bringSubviewToFront(recordButton)
    }
    /*
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
            AVEncoderAudioQualityKey : AVAudioQuality.High.textValue
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
    override var canBecomeFirstResponder : Bool {
        return true
    }
    override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        if (motion == UIEventSubtype.motionShake){
            wasShaken = true
            shakenTimer = Timer.scheduledTimer(timeInterval: TimeInterval(5), target: self, selector: #selector(ViewController.expireShake), userInfo: nil, repeats: false)
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
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = manager.location!.coordinate
    }
    //end location
    
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
    //get ip
    // Return IP address of WiFi interface (en0) as a String, or `nil`
    func getWiFiAddress() -> String? {
        var address : String?
        
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0 {
            
            // For each interface ...
            var ptr = ifaddr
            while(ptr != nil) {
                let interface = ptr?.pointee
                
                // Check for IPv4 or IPv6 interface:
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                    
                    // Check interface name:
                    if let name = String(validatingUTF8: (interface?.ifa_name)!), name == "en0" {
                        
                        // Convert interface address to a human readable string:
                        var addr = interface?.ifa_addr.pointee
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(&addr!, socklen_t((interface?.ifa_addr.pointee.sa_len)!),
                            &hostname, socklen_t(hostname.count),
                            nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            ptr = ptr?.pointee.ifa_next
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
    
    func handleBadRequest(_ name: String) {
        NSLog("Attempted to send command to invalid device: " + name)
        NSLog("Devices found in disovery" + self.sharedBluetoothDiscovery.getDiscovered().keys.joined(separator: ", "))
        self.sharedBluetoothDiscovery.startScan()
    }
    //end orientation
    deinit{
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: BluetoothStatusChangedNotification), object: nil)
    }
    func prepareServer(){
        server["/hummingbird/:param1/out/led/:param2/:param3"] = { request in
            let captured = request.params

            let name = captured[":param1"]?.removingPercentEncoding
            if(self.hbServes.keys.contains(name!) == false) {
                self.handleBadRequest(name!)
                return .ok(.text("Not connected!"))
            }
            let portInt = Int(captured[":param2"]!)
            
            let temp = Int(round((captured[":param3"]! as NSString).floatValue))
            var intensity: UInt8
            
            if (portInt > 4 || portInt < 1){
                return .ok(.text("Invalid Port (should be between 1 and 4 inclusively)"))
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
            self.hbServes[name!]!.setLED(port, intensity: intensity)
            Thread.sleep(forTimeInterval: self.responseTime);
            return .ok(.text("LED set"))
        }
        server["/hummingbird/:param1/out/stop"] = { request in
            let captured = request.params
            
            let name = captured[":param1"]?.removingPercentEncoding
            if(self.hbServes.keys.contains(name!) == false) {
                self.handleBadRequest(name!)
                return .ok(.text("Not connected!"))
            }
            self.hbServes[name!]!.setLED(1, intensity: 0)
            self.hbServes[name!]!.setLED(2, intensity: 0)
            self.hbServes[name!]!.setLED(3, intensity: 0)
            self.hbServes[name!]!.setLED(4, intensity: 0)
            self.hbServes[name!]!.setTriLED(1, r: 0, g: 0, b: 0)
            self.hbServes[name!]!.setTriLED(2, r: 0, g: 0, b: 0)
            self.hbServes[name!]!.setMotor(1, speed: 0)
            self.hbServes[name!]!.setMotor(2, speed: 0)
            self.hbServes[name!]!.setVibration(1, intensity: 0)
            self.hbServes[name!]!.setVibration(2, intensity: 0)
            Thread.sleep(forTimeInterval: self.responseTime);
            return .ok(.text("Turned off outputs"))
        }
        
        server.GET["/hummingbird/out/stopAll"] = { request in
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
            return .ok(.text("Turned off all outputs for all Hummingbirds"))
        }
        server["/hummingbird/:param1/out/triled/:param2/:param3/:param4/:param5"] = { request in
            let captured = request.params
            
            let name = captured[":param1"]?.removingPercentEncoding
            if(self.hbServes.keys.contains(name!) == false) {
                self.handleBadRequest(name!)
                return .ok(.text("Not connected!"))
            }
            let portInt = Int(captured[":param2"]!)
            var temp = Int(round((captured[":param3"]! as NSString).floatValue))
            var rValue: UInt8
            
            if (portInt > 2 || portInt < 1){
                return .ok(.text("Invalid Port (should be between 1 and 4 inclusively)"))
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
            temp = Int(round((captured[":param4"]! as NSString).floatValue))
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
            temp = Int(round((captured[":param5"]! as NSString).floatValue))
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
            self.hbServes[name!]!.setTriLED(port, r: rValue, g: gValue, b: bValue)
            Thread.sleep(forTimeInterval: self.responseTime);
            return .ok(.text("Tri-LED set"))
        }
        server["/hummingbird/:param1/out/vibration/:param2/:param3"] = { request in
            let captured = request.params
            let name = captured[":param1"]?.removingPercentEncoding
            if(self.hbServes.keys.contains(name!) == false) {
                self.handleBadRequest(name!)
                return .ok(.text("Not connected!"))
            }
            let portInt = Int(captured[":param2"]!)
            let temp = Int(round((captured[":param3"]! as NSString).floatValue))
            var intensity: UInt8
            
            
            if (portInt > 2 || portInt < 1){
                return .ok(.text("Invalid Port (should be between 1 and 4 inclusively)"))
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
            
            self.hbServes[name!]!.setVibration(port, intensity: intensity)
            Thread.sleep(forTimeInterval: self.responseTime);
            return .ok(.text("Vibration set"))
        }
        server["/hummingbird/:param1/out/servo/:param2/:param3"] = { request in
            let captured = request.params
            let name = captured[":param1"]?.removingPercentEncoding
            if(self.hbServes.keys.contains(name!) == false) {
                self.handleBadRequest(name!)
                return .ok(.text("Not connected!"))
            }
            let portInt = Int(captured[":param2"]!)
            let temp = Int(round((captured[":param3"]! as NSString).floatValue))
            if (portInt > 4 || portInt < 1){
                return .ok(.text("Invalid Port (should be between 1 and 4 inclusively)"))
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
            
            self.hbServes[name!]!.setServo(port, angle: angle)
            Thread.sleep(forTimeInterval: self.responseTime);
            return .ok(.text("Servo set"))
        }
        server["/hummingbird/:param1/out/motor/:param2/:param3"] = { request in
            let captured = request.params
            let name = captured[":param1"]?.removingPercentEncoding
            if(self.hbServes.keys.contains(name!) == false) {
                self.handleBadRequest(name!)
                return .ok(.text("Not connected!"))
            }
            let portInt = Int(captured[":param2"]!)
            let temp = Int(round((captured[":param3"]! as NSString).floatValue))
            var intensity: Int

            if (portInt > 2 || portInt < 1){
                return .ok(.text("Invalid Port (should be between 1 and 4 inclusively)"))
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
            self.hbServes[name!]!.setMotor(port, speed: intensity)
            Thread.sleep(forTimeInterval: self.responseTime);
            return .ok(.text("Motor set"))
        }
        server["/hummingbird/:param1/in/sensors"] = { request in
            let name = request.params[":param1"]?.removingPercentEncoding
            if(self.hbServes.keys.contains(name!) == false) {
                self.handleBadRequest(name!)
                return .ok(.text("Not connected!"))
            }
            var sensorData = self.hbServes[name!]!.getAllSensorDataFromPoll()
            let response: String = "" + String(rawto100scale(sensorData[0])) + " " + String(rawto100scale(sensorData[1])) + " " + String(rawto100scale(sensorData[2])) + " " + String(rawto100scale(sensorData[3]))
            return .ok(.text(response))
        }
        server["/hummingbird/:param1/in/sensor/:param2"] = { request in
            let captured = request.params
            let name = captured[":param1"]?.removingPercentEncoding
            if(self.hbServes.keys.contains(name!) == false) {
                self.handleBadRequest(name!)
                return .ok(.text("Not connected!"))
            }
            let portInt = Int(captured[":param2"]!)
            if (portInt > 4 || portInt < 1){
                return .ok(.text("Invalid Port (should be between 1 and 4 inclusively)"))
            }
            let port = UInt8(portInt!)
            
            let sensorData = rawto100scale(self.hbServes[name!]!.getSensorDataFromPoll(port))
            let response: String = String(sensorData)
            return .ok(.text(response))
        }
        server["/hummingbird/:param1/in/distance/:param2"] = { request in
            let captured = request.params
            let name = captured[":param1"]?.removingPercentEncoding
            if(self.hbServes.keys.contains(name!) == false) {
                self.handleBadRequest(name!)
                return .ok(.text("Not connected!"))
            }
            let portInt = Int(captured[":param2"]!)
            if (portInt > 4 || portInt < 1){
                return .ok(.text("Invalid Port (should be between 1 and 4 inclusively)"))
            }
            let port = UInt8(portInt!)
            
            let sensorData = rawToDistance(self.hbServes[name!]!.getSensorDataFromPoll(port))
            let response: String = String(sensorData)
            return .ok(.text(response))
        }
        server["/hummingbird/:param1/in/sound/:param2"] = { request in
            let captured = request.params
            let name = captured[":param1"]?.removingPercentEncoding
            if(self.hbServes.keys.contains(name!) == false) {
                self.handleBadRequest(name!)
                return .ok(.text("Not connected!"))
            }
            let portInt = Int(captured[":param2"]!)
            if (portInt > 4 || portInt < 1){
                return .ok(.text("Invalid Port (should be between 1 and 4 inclusively)"))
            }
            let port = UInt8(portInt!)
            
            let sensorData = rawToSound(self.hbServes[name!]!.getSensorDataFromPoll(port))
            let response: String = String(sensorData)
            return .ok(.text(response))
        }
        server["/hummingbird/:param1/in/temperature/:param2"] = { request in
            let captured = request.params
            let name = (captured[":param1"]?.removingPercentEncoding)!
            if(self.hbServes.keys.contains(name) == false) {
                self.handleBadRequest(name)
                return .ok(.text("Not connected!"))
            }
            let portInt = Int(captured[":param2"]!)
            if (portInt > 4 || portInt < 1){
                return .ok(.text("Invalid Port (should be between 1 and 4 inclusively)"))
            }
            let port = UInt8(portInt!)
            
            let sensorData = rawToTemp(self.hbServes[name]!.getSensorDataFromPoll(port))
            let response: String = String(sensorData)
            return .ok(.text(response))
        }
        server["/hummingbird/:param1/status"] = { request in
            let name = (request.params[":param1"]?.removingPercentEncoding)!
            let response = (self.hbServes[name] != nil) ? 1 : 0
            return .ok(.text(String(response)))
        }
        server["/hummingbird/:param1/rename/:param2"] = { request in
            let nameFrom = (request.params[":param1"]?.removingPercentEncoding)!
            if(self.hbServes.keys.contains(nameFrom) == false) {
                self.handleBadRequest(nameFrom)
                return .ok(.text("Not connected!"))
            }
            let nameTo = (request.params[":param2"]?.removingPercentEncoding)!
            if self.hbServes[nameFrom] != nil {
                if let newName = self.hbServes[nameFrom]!.renameDevice(nameTo) {
                    self.hbServes[newName] = self.hbServes.removeValue(forKey: nameFrom)
                    self.hbServes[newName]!.setName(newName)
                    NSLog("number of items in HBSERVE: " + String(self.hbServes.count))
                    return .ok(.text("Renamed"))
                }
            }
            return .ok(.text("Name not found!"))
        }
        server.GET["/hummingbird/names"] = { request in
            let names = Array(self.hbServes.keys.lazy).joined(separator: "\n")
            return .ok(.text(names))
        }
        server.GET["/hummingbird/connectedNames"] = {request in
            let names = self.sharedBluetoothDiscovery.getConnected().joined(separator: "\n")
            return .ok(.text(names))
        }
        server.GET["/hummingbird/serviceNames"] = {request in
            let names = self.sharedBluetoothDiscovery.getServiceNames().joined(separator: "\n")
            return .ok(.text(names))
        }
        server.GET["/hummingbird/ALLNames"] = {request in
            let names = self.sharedBluetoothDiscovery.getAllNames().joined(separator: "\n")
            return .ok(.text(names))
        }
        server["/hummingbird/:param1/disconnect"] = { request in
            let name = (request.params[":param1"]?.removingPercentEncoding)!
            if(self.hbServes.keys.contains(name) == false) {
                self.handleBadRequest(name)
                self.sharedBluetoothDiscovery.removeConnected(name)
                return .ok(.text("Not connected!"))
            }
            self.hbServes[name]!.disconnectFromDevice()
            if (self.hbServes.keys.contains(name)) {
                self.hbServes.removeValue(forKey: name)
            }
            return .ok(.text("Disconnected"))
        }
        server.GET["/hummingbird/discover"] = { request in
            self.sharedBluetoothDiscovery.startScan()
            let dict = self.sharedBluetoothDiscovery.getDiscovered()
            let strings = Array(dict.keys.lazy)
            return .ok(.text(strings.joined(separator: "\n")))
        }
        server.GET["/hummingbird/ForceDiscover"] = { request in
            print("CALLED FORCE!")
            self.sharedBluetoothDiscovery.restartScan()
            let dict = self.sharedBluetoothDiscovery.getDiscovered()
            let strings = Array(dict.keys.lazy)
            return .ok(.text(strings.joined(separator: "\n")))
        }
        server.GET["/hummingbird/totalStatus"] = { request in
            let connectedCount = self.sharedBluetoothDiscovery.getConnected().count
            let hbServeCount = self.hbServes.count
            if (connectedCount == 0) {
                return .ok(.text("2"))
            }
            if (connectedCount == hbServeCount) {
                return .ok(.text("1"))
            } else {
                
                return .ok(.text("0"))
            }
        }
        server["/hummingbird/:param1/connect"] = { request in
            let name = (request.params[":param1"]?.removingPercentEncoding)!
            if let peripheral = self.sharedBluetoothDiscovery.getDiscovered()[name] {
                let hbServe = HummingbirdServices()
                self.hbServes[name] = hbServe
                self.hbServes[name]!.attachToDevice(name)
                self.sharedBluetoothDiscovery.connectToPeripheral(peripheral, name: name)
                return .ok(.text("Connected!"))
            } else {
                print(name)
                print(self.sharedBluetoothDiscovery.getDiscovered())
                return .ok(.text("Device not found"))
            }
        }
        server["/speak/:param1"] = { request in
            let captured = request.params
            let words = (captured[":param1"]?.removingPercentEncoding)!
            let utterance = AVSpeechUtterance(string: words)
            utterance.rate = 0.3
            self.synth.speak(utterance)
            return .ok(.text(words))
            
        }
        server["/iPad/shake"] = {request in
            let checkShake = self.checkShaken()
            if checkShake{
                 return .ok(.text(String(1)))
            }
            return .ok(.text(String(0)))
        }
        server["/iPad/location"] = {request in
            let latitude = Double(self.currentLocation.latitude)
            let longitude = Double(self.currentLocation.longitude)
            let retString = NSString(format: "%f %f", latitude, longitude)
            return .ok(.text(String(retString)))
        }
        server["/iPad/ssid"] = {request in
            let ssid = self.getSSIDInfo()
            return .ok(.text(ssid))
        }
        server["/iPad/pressure"] = {request in
            return .ok(.text(String(format: "%f", self.currentPressure)))
        }
        server["/iPad/altitude"] = {request in
            return .ok(.text(String(format: "%f", self.currentAltitude)))
        }
        server["/iPad/acceleration"] = {request in
            return .ok(.text(String(format: "%f %f %f", self.x, self.y, self.z)))
        }
        server["/iPad/orientation"] = {request in
            return .ok(.text(self.getOrientation()))
        }
        server["/iPad/choice/:param1/:param2/:param3/:param4"] = { request in
            NSLog("choice called");
            self.last_choice_response = 0
            let captured = request.params
            let title = (captured[":param1"]?.removingPercentEncoding)!
            let question = (captured[":param2"]?.removingPercentEncoding)!
            let button1Text = (captured[":param3"]?.removingPercentEncoding)!
            let button2Text = (captured[":param4"]?.removingPercentEncoding)!
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
                NSLog("choice opened view controller")
                
            }
            return .ok(.text("Choice Dialog Presented"))

        }
        server["/iPad/choice_response"] = {request in
            return .ok(.text(String(self.last_choice_response)))
        }
        server["/iPad/dialog/:param1/:param2/:param3"] = {request in
            NSLog("dialog called");
            self.last_dialog_response = nil
            let captured = request.params
            let title = (captured[":param1"]?.removingPercentEncoding)!
            let question = (captured[":param2"]?.removingPercentEncoding)!
            let answerHolder = (captured[":param3"]?.removingPercentEncoding)!
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
                print("ABOUT TO DISPLAY")
                //self.navigationController?.pushViewController(alertController, animated: true)
                UIApplication.shared.keyWindow?.rootViewController!.present(alertController, animated: true, completion: nil)
                print("DISPLAYED")
            }
            return .ok(.text("Dialog Presented"))
        }
        server["/iPad/dialog_response"] = {request in
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
        server["/data/files"] = {request in
            let fileList = getSavedFileNames()
            var files: String = "";
            fileList.forEach({ (string) in
                files.append(string)
                files.append("\n")
            })
            return .ok(.text(files))
        }
        server["/data/filename"] = {request in
            if let filename = self.currentFileName {
                return .ok(.text(filename))
            } else {
                return .ok(.text("File has no name."))
            }
        }
        server["/data/load/:param1"] = {request in
            let filename = request.params[":param1"]?.removingPercentEncoding
            let fileContent = getSavedFileByName(filename!)
            if (fileContent == "File not found") {
                return .ok(.text("File Not Found"))
            }
            self.currentFileName = filename?.replacingOccurrences(of: ".bbx", with: "")
            return .ok(.text(fileContent as (String)))
        }
        server["/data/save/:param1"] = {request in
            NSLog("GOT SAVE")
            let filename = (request.params[":param1"]?.removingPercentEncoding)!
            let requestForms = request.parseUrlencodedForm()
            var body: String? = nil
            for form in requestForms {
                if form.0 == "data" {
                    body = form.1
                    break
                }
            }
            if let requestBody = body {
                let xml: String = requestBody.replacingOccurrences(of: "data=", with: "")
                //print(xml)
                saveStringToFile(xml as NSString, fileName: filename)
                self.currentFileName = filename
                return .ok(.text("Saved"))
            } else {
                NSLog("Bodyless")
                return .ok(.text("darn"))
            }
        }
        server["/data/export/:param1"] = {request in
            let filename = (request.params[":param1"]?.removingPercentEncoding)!
            let requestForms = request.parseUrlencodedForm()
            var body: String? = nil
            for form in requestForms {
                if form.0 == "data" {
                    body = form.1
                    break
                }
            }
            if let requestBody = body {
                let xml: String = requestBody.replacingOccurrences(of: "data=", with: "")
                saveStringToFile(xml as NSString, fileName: filename)
                self.currentFileName = filename
                let exportedPath = getSavedFileURL(filename)
                let url = URL(fileURLWithPath: exportedPath.path)
                print(url.absoluteString)
                let view = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                view.popoverPresentationController?.sourceView = self.mainWebView
                view.excludedActivityTypes = nil
                DispatchQueue.main.async{
                    self.present(view, animated: true, completion: nil)
                }
            }
            return .ok(.text("Done"))
        }
        server["/data/delete/:param1"] = {request in
            let filename = request.params[":param1"]?.removingPercentEncoding
            let result = deleteFile(filename!)
            if (result == false) {
                return .ok(.text("File Not Found"))
            }
            if (self.currentFileName == filename) {
                self.currentFileName = nil
            }
            return .ok(.text("File Deleted"))
        }
        server["/data/rename/:param1/:param2"] = {request in
            let captured = request.params
            let filename = (captured[":param1"]?.removingPercentEncoding)!
            let newFilename = (captured[":param2"]?.removingPercentEncoding)!
            
            let result = renameFile(filename, newFileName: newFilename)
            if (result == false) {
                return .ok(.text("File Not Found"))
            }
            if (self.currentFileName == filename) {
                self.currentFileName = newFilename
            }
            return .ok(.text("File Renamed"))
        }
        server["/data/new"] = {request in
            self.currentFileName = nil
            return .ok(.text("Filename reset"))
        }
        server["/data/saveAsNew"] = {request in
            self.tempNew = true
            return .ok(.text("Filename temporarily cleared"))
        }
        
        server["/data/autosave"] = {request in
            let requestForms = request.parseUrlencodedForm()
            var body: String? = nil
            for form in requestForms {
                if form.0 == "data" {
                    body = form.1
                    break
                }
            }
            if let requestBody = body {
                let xml: String = requestBody.replacingOccurrences(of: "data=", with: "")
                autosave(xml as NSString)
                return .ok(.text("Saved"))
            } else {
                return .ok(.text("darn"))
            }
        }
        server["/data/loadAutosave"] = {request in
            let fileContent = getSavedFileByName("autosaveFile")
            if (fileContent == "File not found") {
                return .ok(.text("File Not Found"))
            }
            self.currentFileName = "autosaveFile"
            return .ok(.text(fileContent as (String)))
        }
        
        
        server["/server/ping"] = {request in
            return .ok(.text("pong"))
        }
        server["/server/log/:param1"] = {request in
            let data = request.params[":param1"]!
            NSLog(data)
            return .ok(.text(data))
        }
        server["/iPad/screenSize"] = {request in
            let screenSize: CGRect = UIScreen.main.bounds
            let width = String(describing: screenSize.width)
            let height = String(describing: screenSize.height)
            return .ok(.text(height + "\n" + width))
        }
        server["/iPad/ip"] = {request in
            if (self.isConnectedToInternet()) {
                if let ip = self.getWiFiAddress() {
                    return .ok(.text(ip))
                }
            }
            return .ok(.text("0.0.0.0"))
        }
        server["sound/note/:param1/:param2"] = {request in
            let captured = request.params
            let note: UInt = UInt(captured[":param1"]!)!
            let duration: Int = Int(captured[":param2"]!)!
            self.audioManager.playNote(noteIndex: note, duration: duration)
            return .ok(.text("Sound?"))
        }
        server["sound/names"] = {request in
            let soundList = getSoundNames()
            var sounds: String = "";
            soundList.forEach({ (string) in
                sounds.append(string)
                sounds.append("\n")
            })
            return .ok(.text(sounds))
        }
        server["sound/duration/:param1"] = {request in
            let filename = request.params[":param1"]!
            return .ok(.text(String(self.audioManager.getSoundDuration(filename: filename))))
        }
        server["sound/play/:param1"] = {request in
            let filename = request.params[":param1"]!
            self.audioManager.playSound(filename: filename)
            return .ok(.text("Playing sound"))
        }
        server["sound/stop"] = {request in
            self.audioManager.stopSounds()
            return .ok(.text("Sounds Stopped"))
        }
        server["sound/stopAll"] = {request in
            self.audioManager.stopTones()
            self.audioManager.stopSounds()
            return .ok(.text("Sounds All Audio"))

        }
        /*server["/project.bbx"] = {request in
            if let importText = self.importedXMLText{
                self.importedXMLText = nil
                return .OK(.text(importText))
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
                return .OK(.text(rawText))
            } catch {
                print("Error: Couldn't get contents of XML file\n")
                let rawText = ""
                return .OK(.text(rawText))
            }
        }*/
        server["/settings/get/:param1"] = {request in
            let key = (request.params[":param1"]?.removingPercentEncoding)!
            let value = getSetting(key)
            if let nullCheckedValue = value {
                return .ok(.text(nullCheckedValue))
            } else {
                return .ok(.text("Default"))
            }
        }
        server["/settings/set/:param1/:param2"] = {request in
            let captured = request.params
            let key = (captured[":param1"]?.removingPercentEncoding)!
            let value = (captured[":param2"]?.removingPercentEncoding)!
            addSetting(key, value: value)
            return .ok(.text("Setting saved"))
        }
        server["/settings/delete/key/:param1"] = {request in
            let key = (request.params[":param1"]?.removingPercentEncoding)!
            removeSetting(key)
            return .ok(.text("Setting Deleted"))
        }
        /*
        server["/DragAndDrop/Block/:path"] = directoryBrowser(getPath2().path)
        server["/DragAndDrop/BlockContainers/:path"] = directoryBrowser(getPath2().path)
        server["/DragAndDrop/BlockDefsAndList/:path"] = directoryBrowser(getPath2().path)
        server["/DragAndDrop/BlockParts/:path"] = directoryBrowser(getPath2().path)
        server["/DragAndDrop/ColorsAndGraphics/:path"] = directoryBrowser(getPath2().path)
        server["/DragAndDrop/Data/:path"] = directoryBrowser(getPath2().path)
        server["/DragAndDrop/Images/:path"] = directoryBrowser(getPath2().path)
        server["/DragAndDrop/SoundClips/:path"] = directoryBrowser(getPath2().path)
        server["/DragAndDrop/SVGIcons/:path"] = directoryBrowser(getPath2().path)
        server["/DragAndDrop/UIParts/:path"] = directoryBrowser(getPath2().path)
        */
        server["/DragAndDrop/:param1/"] = { request in
            let captured = request.params
            let path1 = (captured[":param1"]?.removingPercentEncoding)!
            if path1 != ""{
                let path = getPath().appendingPathComponent(path1)
                guard let file = try? path.path.openForReading() else {
                    return .notFound
                }
                return .raw(200, "OK", [:], { writer in
                    try? writer.write(file)
                    file.close()
                })
            } else {
                return .notFound
            }
        }
        server["/DragAndDrop/:param1/:param2/:param3"] = { request in
            let captured = request.params
            let path1 = (captured[":param1"]?.removingPercentEncoding)!
            let path2 = (captured[":param2"]?.removingPercentEncoding)!
            let path3 = (captured[":param3"]?.removingPercentEncoding)!
            if path3 != "" {
                let path = getPath().appendingPathComponent(path3)
                guard let file = try? path.path.openForReading() else {
                    return .notFound
                }
                return .raw(200, "OK", [:], { writer in
                    try? writer.write(file)
                    file.close()
                })
            } else if path2 != "" {
                let path = getPath().appendingPathComponent(path2)
                guard let file = try? path.path.openForReading() else {
                    return .notFound
                }
                return .raw(200, "OK", [:], { writer in
                    try? writer.write(file)
                    file.close()
                })
            } else if path1 != ""{
                let path = getPath().appendingPathComponent(path1)
                guard let file = try? path.path.openForReading() else {
                    return .notFound
                }
                return .raw(200, "OK", [:], { writer in
                    try? writer.write(file)
                    file.close()
                })
            } else {
                return .notFound
            }
        }


        NSLog("Server prepared")
    }
    func changedStatus(_ notification: Notification){
        let userinfo = notification.userInfo as! [String: AnyObject]
        NSLog("View controller got notification: " + notification.name.rawValue)
        if let name: String = userinfo["name"] as? String {
            NSLog("Got name " + name)
            if let isConnected: Bool = userinfo["isConnected"] as? Bool{
                NSLog("Got connection status")
                if isConnected{
                    NSLog("device connected:" + name)
                    if(hbServes[name] == nil) {
                        let hbServe = HummingbirdServices()
                        self.hbServes[name] = hbServe
                        self.hbServes[name]!.attachToDevice(name)
                    }
                    hbServes[name]!.turnOffLightsMotor()
                    Thread.sleep(forTimeInterval: 0.1)
                    hbServes[name]!.stopPolling()
                    Thread.sleep(forTimeInterval: 0.1)
                    hbServes[name]!.beginPolling()
                    DispatchQueue.main.async{
                        //self.connectedIndicator.textColor = UIColor.greenColor()
                    }
                }
                else{
                    NSLog("device disconnected:" + name)
                    DispatchQueue.main.async{
                        //self.connectedIndicator.textColor = UIColor.redColor()
                        if (self.hbServes.keys.contains(name)) {
                            self.hbServes.removeValue(forKey: name)
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

