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

    @IBOutlet weak var importButton: UIButton!
    @IBOutlet weak var recordButton: UIButton!
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
    var mainWebView: WKWebView!
    var importedXMLText: String?
    var recorder: AVAudioRecorder?
    
    override func loadView() {
        super.loadView()
        mainWebView = WKWebView(frame: self.view.bounds)
        mainWebView.UIDelegate = self
        mainWebView.contentMode = UIViewContentMode.ScaleAspectFit
    }
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
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
    
    func mailComposeController(controller: MFMailComposeViewController, didFinishWithResult result: MFMailComposeResult, error: NSError?) {
        self.dismissViewControllerAnimated(true, completion: nil)
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardDidShow:", name: UIKeyboardDidShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardDidHide:", name: UIKeyboardDidHideNotification, object: nil)
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
        prepareServer()
        server.start(22180)
        
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
                let connectionAlert = UIAlertController(title: "Connected", message: "The app is currently connecting to a local version of Snap!. If you would like to use the app as a server, simply open the iPad starter project or a project built from it on a computer and use this IP address: " + ip, preferredStyle: UIAlertControllerStyle.Alert)
                connectionAlert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
                self.presentViewController(connectionAlert, animated: true, completion: nil)
            }
            else{
                let connectionAlert = UIAlertController(title: "Connected", message: "The app is currently connecting to a local version of Snap!. If you would like to use the app as a server, you need to be connected to wifi. Either you are not connected to wifi or have some connection connection issues.", preferredStyle: UIAlertControllerStyle.Alert)
                connectionAlert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
                self.presentViewController(connectionAlert, animated: true, completion: nil)
            }
            let url = NSURL(string: "http://localhost:22180/snap/snap.html#open:http://localhost:22180/project.xml")
            //let url = NSURL(string: "http://snap.berkeley.edu/snapsource/snap.html")
            let requestPage = NSURLRequest(URL: url!)
            self.view.addSubview(mainWebView)
            mainWebView?.loadRequest(requestPage)
        }
        else{
            let noConnectionAlert = UIAlertController(title: "Cannot Connect", message: "This app required an internet connection for certain features to work. There is currently no connection avaliable. If this is your first time opening the app, it will NOT load. You need to open the app while you have internet at least once so that the snap source code can be downloaded", preferredStyle: UIAlertControllerStyle.Alert)
            noConnectionAlert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
            self.presentViewController(noConnectionAlert, animated: true, completion: nil)
            let url = NSURL(string: "http://localhost:22180/snap/snap.html#open:http://localhost:22180/project.xml")
            let requestPage = NSURLRequest(URL: url!)
            self.view.addSubview(mainWebView)
            mainWebView?.loadRequest(requestPage)
        }
        self.view.bringSubviewToFront(importButton)
        self.view.bringSubviewToFront(recordButton)
    }
    @IBAction func importPressed(sender: UIButton) {
        var xmlField: UITextField?
        func didPasteFile(alert: UIAlertAction!){
            importedXMLText = xmlField?.text
            let url = NSURL(string: "http://localhost:22180/snap/snap.html#open:http://localhost:22180/project.xml")
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
        }
        server["/snap/(.+)"] = HttpHandlers.directoryBrowser(getSnapPath().path!)
        server["/snap/Backgrounds/(.+)"] = HttpHandlers.directoryBrowser(getSnapPath().URLByAppendingPathComponent("Backgrounds").path!)
        server["/snap/Costumes/(.+)"] = HttpHandlers.directoryBrowser(getSnapPath().URLByAppendingPathComponent("Costumes").path!)
        server["/snap/Sounds/(.+)"] = HttpHandlers.directoryBrowser(getSnapPath().URLByAppendingPathComponent("Sounds").path!)
        server["/snap/Sounds"] = HttpHandlers.directoryBrowser(getSnapPath().URLByAppendingPathComponent("Sounds").path!)
        server["/snap/Examples/(.+)"] = HttpHandlers.directoryBrowser(getSnapPath().URLByAppendingPathComponent("Examples").path!)
        server["/snap/help/(.+)"] = HttpHandlers.directoryBrowser(getSnapPath().URLByAppendingPathComponent("help").path!)
        server["/snap/libraries/(.+)"] = HttpHandlers.directoryBrowser(getSnapPath().URLByAppendingPathComponent("libraries").path!)
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

