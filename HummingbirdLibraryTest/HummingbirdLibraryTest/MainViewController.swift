//
//  ViewController.swift
//  HummingbirdLibraryTest
//
//  Created by birdbrain on 5/28/15.
//  Copyright (c) 2015 Birdbrain Technologies LLC. All rights reserved.
//

import UIKit
//import HummingbirdLibrary

class MainViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    //stuff for the picker views for picking a sensor
    let pickerSource = ["Temperature", "Distance", "Voltage", "Sound", "Rotary", "Light"]
    var picker: [UInt] = [0,1,3,4]
    
    @IBOutlet weak var pickerButton1: UIButton!
    @IBAction func picker1Click(sender: AnyObject) {
        pickerAlert(0)
    }
    @IBOutlet weak var pickerButton2: UIButton!
    @IBAction func picker2Click(sender: AnyObject) {
        pickerAlert(1)
    }
    @IBOutlet weak var pickerButton3: UIButton!
    @IBAction func picker3Click(sender: AnyObject) {
        pickerAlert(2)
    }
    @IBOutlet weak var pickerButton4: UIButton!
    @IBAction func picker4Click(sender: AnyObject) {
        pickerAlert(3)
    }
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerSource.count
    }
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return pickerSource[row]
    }
    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        picker[pickerView.tag] = UInt(row)
        switch pickerView.tag{
        case 0:
            pickerButton1.setTitle(pickerSource[row], forState: pickerButton1.state)
        case 1:
            pickerButton2.setTitle(pickerSource[row], forState: pickerButton2.state)
        case 2:
            pickerButton3.setTitle(pickerSource[row], forState: pickerButton3.state)
        case 3:
            pickerButton4.setTitle(pickerSource[row], forState: pickerButton4.state)
        default://shouldn't happen
            break;
        }
        
    }
    
    func pickerAlert(pickerNum: Int){
        let pickerAlert: UIAlertController = UIAlertController(title: nil, message: "Please select the type of this sensor\n\n\n\n\n\n", preferredStyle: UIAlertControllerStyle.Alert)
        pickerAlert.modalInPopover = true
        let pickerFrame: CGRect = CGRectMake(10, 50, 250, 100)
        let picker: UIPickerView = UIPickerView(frame: pickerFrame)
        picker.delegate = self
        picker.dataSource = self
        picker.tag = pickerNum
        pickerAlert.view.addSubview(picker)
        let okayAction = UIAlertAction(title: "Okay", style: UIAlertActionStyle.Default,handler: nil)
        pickerAlert.addAction(okayAction)
        pickerAlert.view.sizeToFit()
        self.presentViewController(pickerAlert, animated: true, completion: nil)
        picker.selectRow(Int(self.picker[pickerNum]), inComponent: 0, animated: true)
    }
    //end of picker
    
    //sliders for slider bugfix
    func fixSlider(slider: UISlider){
        slider.setThumbImage(slider.thumbImageForState(.Normal), forState:.Normal)
    }
    
    @IBOutlet weak var led1slider: UISlider!
    @IBOutlet weak var led2slider: UISlider!
    @IBOutlet weak var led3slider: UISlider!
    @IBOutlet weak var led4slider: UISlider!
    @IBOutlet weak var vib1slider: UISlider!
    @IBOutlet weak var vib2slider: UISlider!
    @IBOutlet weak var motor1slider: UISlider!
    @IBOutlet weak var motor2slider: UISlider!
    @IBOutlet weak var servo1slider: UISlider!
    @IBOutlet weak var servo2slider: UISlider!
    @IBOutlet weak var servo3slider: UISlider!
    @IBOutlet weak var servo4slider: UISlider!
    @IBOutlet weak var trired1slider: UISlider!
    @IBOutlet weak var trigreen1slider: UISlider!
    @IBOutlet weak var triblue1slider: UISlider!
    @IBOutlet weak var trired2slider: UISlider!
    @IBOutlet weak var trigreen2slider: UISlider!
    @IBOutlet weak var triblue2slider: UISlider!
    
    func fixAllSliders(){
        fixSlider(led1slider)
        fixSlider(led2slider)
        fixSlider(led3slider)
        fixSlider(led4slider)
        fixSlider(vib1slider)
        fixSlider(vib2slider)
        fixSlider(motor1slider)
        fixSlider(motor2slider)
        fixSlider(servo1slider)
        fixSlider(servo2slider)
        fixSlider(servo3slider)
        fixSlider(servo4slider)
        fixSlider(trired1slider)
        fixSlider(trigreen1slider)
        fixSlider(triblue1slider)
        fixSlider(trired2slider)
        fixSlider(trigreen2slider)
        fixSlider(triblue2slider)
        
    }
    //end of slider fix stuff
    
    //internal record of output values
    var leds: [UInt8] = [0,0,0,0]
    var triLeds: [[UInt8]] = [[0,0,0],[0,0,0]]
    var vibs: [UInt8] = [0,0]
    var motors: [Int] = [0,0]
    var servos: [UInt8] = [0,0,0,0]
    
    var hbServe: HummingbirdServices!
    @IBOutlet weak var statusLabel: UILabel!
    var startupStatus = -999{
        didSet{
            if (startupStatus == 1){
                waitForRestart(newName)
            }
            else if (startupStatus == 3){
                self.presentedViewController?.dismissViewControllerAnimated(true, completion: nil)
                startupStatus = 0
            }
        }
    }
    var newName = ""
    
    override func viewDidLoad() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("changedStatus:"), name: BluetoothStatusChangedNotification, object: nil)
        navigationController!.setNavigationBarHidden(true, animated:true)
        print("view loaded")
        super.viewDidLoad()
        let ios8_2: NSOperatingSystemVersion = NSOperatingSystemVersion(majorVersion: 8, minorVersion: 2, patchVersion: 0);
        if (!NSProcessInfo().isOperatingSystemAtLeastVersion(ios8_2)){
            fixAllSliders()
        }
    }
    
    deinit{
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BluetoothStatusChangedNotification, object: nil)
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setNameAlert(){
        let alertController = UIAlertController(title: "Set Name", message: "Enter a name for your Hummingbird (up to 18 characters)", preferredStyle: UIAlertControllerStyle.Alert)
        let okayAction = UIAlertAction(title: "Okay", style: UIAlertActionStyle.Default){
            (action) -> Void in
            if let textField = alertController.textFields?.first{
                self.newName = (textField as UITextField).text!
                self.startupStatus = 1
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
    @IBAction func setName(sender: AnyObject) {
        setNameAlert()
    }
    func waitForRestart(name: String){
        print("waiting for restart")
        let alertController2 = UIAlertController(title: "Please wait", message: "The Hummingbird bluetooth adapter is processing the request to change its name, this could take up to 30 seconds\n\n\n\n\n", preferredStyle: UIAlertControllerStyle.Alert)
        let spinner = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
        spinner.center = CGPointMake(139.5,125.5)
        spinner.startAnimating()
        alertController2.view.addSubview(spinner)
        print("presenting wait")
        self.presentedViewController?.dismissViewControllerAnimated(true, completion: nil)
        self.presentViewController(alertController2, animated: true, completion: nil)
        print("presented wait")
        self.hbServe.setName(name)
    }
    
    func changedStatus(notification: NSNotification){
        let userinfo = notification.userInfo as! [String: Bool]
        if let isConnected: Bool = userinfo["isConnected"]{
            var statString = ""
            if isConnected{
                print("device connected")
                statString = "Connected"
                hbServe.turnOffLightsMotor()
                leds = [0,0,0,0]
                triLeds = [[0,0,0],[0,0,0]]
                vibs = [0,0]
                motors = [0,0]
                servos = [0,0,0,0]
                NSThread.sleepForTimeInterval(0.1)
                hbServe.stopPolling()
                NSThread.sleepForTimeInterval(0.1)
                hbServe.beginPolling()
                if(startupStatus == 2){
                    startupStatus = 3
                }
            }
            else{
                print("device disconnected")
                statString = "Disconnected"
                if(startupStatus == 1){
                    startupStatus = 2
                }
            }
            dispatch_async(dispatch_get_main_queue(), {
                self.statusLabel.text = statString
            })
        }
    }
    
  
    //UI controls
    
    @IBAction func LED1Slider(sender: UISlider) {
        let newValue = UInt8(sender.value)
        let dif = UInt8(abs(Int(newValue)-Int(leds[0])))
        if(dif>=10 || (newValue == 0 && dif != 0)){
            hbServe.setLED(1, intensity: newValue)
            leds[0] = newValue
        }
    }
    @IBAction func LED2Slider(sender: UISlider) {
        let newValue = UInt8(sender.value)
        let dif = UInt8(abs(Int(newValue)-Int(leds[1])))
        if(dif>=10 || (newValue == 0 && dif != 0)){
            hbServe.setLED(2, intensity: newValue)
            leds[1] = newValue
        }
    }
    @IBAction func LED3Slider(sender: UISlider) {
        let newValue = UInt8(sender.value)
        let dif = UInt8(abs(Int(newValue)-Int(leds[2])))
        if(dif>=10 || (newValue == 0 && dif != 0)){
            hbServe.setLED(3, intensity: newValue)
            leds[2] = newValue
        }
    }
    @IBAction func LED4Slider(sender: UISlider) {
        let newValue = UInt8(sender.value)
        let dif = UInt8(abs(Int(newValue)-Int(leds[3])))
        if(dif>=10 || (newValue == 0 && dif != 0)){
            hbServe.setLED(4, intensity: newValue)
            leds[3] = newValue
        }
    }
    @IBAction func Red1Slider(sender: UISlider) {
        let newValue = UInt8(sender.value)
        let dif = UInt8(abs(Int(newValue)-Int(triLeds[0][0])))
        if(dif>=10 || (newValue == 0 && dif != 0)){
            hbServe.setTriLED(1, r: newValue, g: triLeds[0][1], b: triLeds[0][2])
            triLeds[0][0] = newValue
        }
    }
    @IBAction func Green1Slider(sender: UISlider) {
        let newValue = UInt8(sender.value)
        let dif = UInt8(abs(Int(newValue)-Int(triLeds[0][1])))
        if(dif>=10 || (newValue == 0 && dif != 0)){
            hbServe.setTriLED(1, r: triLeds[0][0], g: newValue, b: triLeds[0][2])
            triLeds[0][1] = newValue
        }
    }
    @IBAction func Blue1Slider(sender: UISlider) {
        let newValue = UInt8(sender.value)
        let dif = UInt8(abs(Int(newValue)-Int(triLeds[0][2])))
        if(dif>=10 || (newValue == 0 && dif != 0)){
            hbServe.setTriLED(1, r: triLeds[0][0], g: triLeds[0][1], b: newValue)
            triLeds[0][2] = newValue
        }
    }
    @IBAction func Red2Slider(sender: UISlider) {
        let newValue = UInt8(sender.value)
        let dif = UInt8(abs(Int(newValue)-Int(triLeds[1][0])))
        if(dif>=10 || (newValue == 0 && dif != 0)){
            hbServe.setTriLED(2, r: newValue, g: triLeds[1][1], b: triLeds[1][2])
            triLeds[1][0] = newValue
        }
    }
    @IBAction func Green2Slider(sender: UISlider) {
        let newValue = UInt8(sender.value)
        let dif = UInt8(abs(Int(newValue)-Int(triLeds[1][1])))
        if(dif>=10 || (newValue == 0 && dif != 0)){
            hbServe.setTriLED(2, r: triLeds[1][0], g: newValue, b: triLeds[1][2])
            triLeds[1][1] = newValue
        }
    }
    @IBAction func Blue2Slider(sender: UISlider) {
        let newValue = UInt8(sender.value)
        let dif = UInt8(abs(Int(newValue)-Int(triLeds[1][2])))
        if(dif>=10 || (newValue == 0 && dif != 0)){
            hbServe.setTriLED(2, r: triLeds[1][0], g: triLeds[1][1], b: newValue)
            triLeds[1][2] = newValue
        }
    }
    @IBAction func Vib1Slider(sender: UISlider) {
        let newValue = UInt8(sender.value)
        let dif = UInt8(abs(Int(newValue)-Int(vibs[0])))
        if(dif>=10 || (newValue == 0 && dif != 0)){
            hbServe.setVibration(1, intensity: newValue)
            vibs[0] = newValue
        }
    }
    @IBAction func Vib2Slider(sender: UISlider) {
        let newValue = UInt8(sender.value)
        let dif = UInt8(abs(Int(newValue)-Int(vibs[1])))
        if(dif>=10 || (newValue == 0 && dif != 0)){
            hbServe.setVibration(2, intensity: newValue)
            vibs[1] = newValue
        }
    }
    @IBOutlet weak var DirectionMotor1: UISegmentedControl!
    @IBAction func Motor1Slider(sender: UISlider) {
        var newValue = Int(sender.value)
        if(DirectionMotor1.selectedSegmentIndex == 1){
            newValue *= -1
        }
        let dif = Int(abs(Int(newValue)-Int(motors[0])))
        if(dif>=10 || (newValue == 0 && dif != 0)){
            hbServe.setMotor(1, speed: newValue)
            motors[0] = newValue
        }
    }
    @IBAction func DirectionChanged1(sender: UISegmentedControl) {
        var newValue = Int(abs(motors[0]))
        if(DirectionMotor1.selectedSegmentIndex == 1){
            newValue *= -1
        }
        let dif = Int(abs(Int(newValue)-Int(motors[0])))
        if(dif>=10 || (newValue == 0 && dif != 0)){
            hbServe.setMotor(1, speed: newValue)
            motors[0] = newValue
        }
    }
    
    
    @IBOutlet weak var DirectionMotor2: UISegmentedControl!
    @IBAction func Motor2Slider(sender: UISlider) {
        var newValue = Int(sender.value)
        if(DirectionMotor2.selectedSegmentIndex == 1){
            newValue *= -1
        }
        let dif = Int(abs(Int(newValue)-Int(motors[1])))
        if(dif>=10 || (newValue == 0 && dif != 0)){
            hbServe.setMotor(2, speed: newValue)
            motors[1] = newValue
        }
    }
    @IBAction func DirectionChanged2(sender: UISegmentedControl) {
        var newValue = Int(abs(motors[1]))
        if(DirectionMotor2.selectedSegmentIndex == 1){
            newValue *= -1
        }
        let dif = Int(abs(Int(newValue)-Int(motors[1])))
        if(dif>=10 || (newValue == 0 && dif != 0)){
            hbServe.setMotor(2, speed: newValue)
            motors[1] = newValue
        }
    }
    
    
    @IBAction func Servo1Slider(sender: UISlider) {
        let newValue = UInt8(sender.value)
        let dif = UInt8(abs(Int(newValue)-Int(servos[0])))
        if(dif>=10 || (newValue == 0 && dif != 0) || (newValue == 180 && dif != 0)){
            hbServe.setServo(1, angle: newValue)
            servos[0] = newValue
        }
    }
    
    @IBAction func Servo2Slider(sender: UISlider) {
        let newValue = UInt8(sender.value)
        let dif = UInt8(abs(Int(newValue)-Int(servos[1])))
        if(dif>=10 || (newValue == 0 && dif != 0) || (newValue == 180 && dif != 0)){
            hbServe.setServo(2, angle: newValue)
            servos[1] = newValue
        }
    }
    
    @IBAction func Servo3Slider(sender: UISlider) {
        let newValue = UInt8(sender.value)
        let dif = UInt8(abs(Int(newValue)-Int(servos[2])))
        if(dif>=10 || (newValue == 0 && dif != 0) || (newValue == 180 && dif != 0)){
            hbServe.setServo(3, angle: newValue)
            servos[2] = newValue
        }
    }
    @IBAction func Servo4Slider(sender: UISlider) {
        let newValue = UInt8(sender.value)
        let dif = UInt8(abs(Int(newValue)-Int(servos[3])))
        if(dif>=10 || (newValue == 0 && dif != 0) || (newValue == 180 && dif != 0)){
            hbServe.setServo(4, angle: newValue)
            servos[3] = newValue
        }
    }
    @IBOutlet weak var sensor1: UILabel!
    @IBOutlet weak var sensor2: UILabel!
    @IBOutlet weak var sensor3: UILabel!
    @IBOutlet weak var sensor4: UILabel!
    
    func convertValue(sensorType: UInt, value: UInt8) -> Int{
        switch sensorType{
        case 0://Temp
            return rawToTemp(value);
        case 1://Distance
            return rawToDistance(value)
        case 2://Voltage
            return rawToVoltage(value)
        case 3://Sound
            return rawToSound(value)
        case 4://Rotary
            return rawToRotary(value)
        case 5://Light
            return rawToLight(value)
        default:
            //this should not happen
            return Int(value);
        }
    }
    
    @IBAction func updateSensor1(sender: AnyObject) {
        let data: UInt8 = hbServe.getSensorDataFromPoll(1)
        sensor1.text = String(convertValue(picker[0], value: data))
    }
    
    @IBAction func updateSensor2(sender: AnyObject) {
        let data: UInt8 = hbServe.getSensorDataFromPoll(2)
        sensor2.text = String(convertValue(picker[1], value: data))
    }
    @IBAction func updateSensor3(sender: AnyObject) {
        let data: UInt8 = hbServe.getSensorDataFromPoll(3)
        sensor3.text = String(convertValue(picker[2], value: data))
    }
    @IBAction func updateSensor4(sender: AnyObject) {
        let data: UInt8 = hbServe.getSensorDataFromPoll(4)
        sensor4.text = String(convertValue(picker[3], value: data))
    }
    
    func updateSensorInfo(){
        var data: [UInt8] = hbServe.getAllSensorDataFromPoll()
        sensor1.text = String(convertValue(picker[0], value: data[0]))
        sensor2.text = String(convertValue(picker[1], value: data[1]))
        sensor3.text = String(convertValue(picker[2], value: data[2]))
        sensor4.text = String(convertValue(picker[3], value: data[3]))
    }
    @IBAction func updateAllSensors(sender: AnyObject) {
        updateSensorInfo()
    }
    
    var constantUpdateTimer = NSTimer()
    @IBAction func constantPoll(sender: UISwitch) {
        print("switch toggled")
        if(sender.on){
            link1Timer = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: Selector("updateSensorInfo"), userInfo: nil, repeats: true)
        }else{
            link1Timer.invalidate()
        }
    }
    var link1Timer = NSTimer()
    @IBAction func link1to1(sender: UISwitch) {
        print("switch toggled")
        if(sender.on){
            link1Timer = NSTimer.scheduledTimerWithTimeInterval(0.0, target: self, selector: Selector("setLED1fromSensor1"), userInfo: nil, repeats: true)
        }else{
            link1Timer.invalidate()
        }
    }
    
    func setLED1fromSensor1(){
            let currentValue = hbServe.getSensorDataFromPoll(1)
            let value = UInt8(abs(self.convertValue(self.picker[0], value: currentValue)))
            let dif = UInt8(abs(Int(value)-Int(self.leds[0])))
            if(dif != 0){
                self.hbServe.setLED(1, intensity: value)//set LED
                self.leds[0] = value
            }
    }
}

