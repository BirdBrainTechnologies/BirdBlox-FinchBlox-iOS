//
//  ViewController.swift
//  BirdBlox
//
//  Created by birdbrain on 3/21/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import UIKit
import WebKit

class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    var wasShaken: Bool = false
    var shakenTimer: Timer = Timer()
	var wv: WKWebView? = nil
	
	var webUILoaded = false
	
	
    override func viewDidLoad() {
		print("viewDidLoad")
        super.viewDidLoad()
		
		//Setup Server
		self.addHandlersToServer((UIApplication.shared.delegate as! AppDelegate).backendServer)
		(UIApplication.shared.delegate as! AppDelegate).backendServer.start()
		
		
		//Setup webview
		let webView = WKWebView()
		self.wv = webView
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.contentMode = UIViewContentMode.scaleToFill
		webView.backgroundColor = UIColor.white
		
		let urlstr = "http://localhost:22179/DragAndDrop/HummingbirdDragAndDrop.html";
		let cleanUrlStr = urlstr.addingPercentEncoding(withAllowedCharacters:
														CharacterSet.urlFragmentAllowed)!
		let javascriptPageURL = URL(string: cleanUrlStr)
		let req = URLRequest(url: javascriptPageURL!,
		             cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalCacheData)
		
        webView.load(req)
		self.view = webView
    }
	
	//MARK: Setup Sever
	let hummingbirdManager = HummingbirdManager()
	let flutterManager = FlutterManager()
	let soundManager = SoundManager()
	let settingsManager = SettingsManager()
	let propertiesManager = PropertiesManager()
	
	var dataRequests: DataManager? = nil
	var hostDeviceManager: HostDeviceManager? = nil
	
	func addHandlersToServer(_ server: BBTBackendServer) {
		dataRequests = dataRequests != nil ? dataRequests :  DataManager(view_controller: self)
		hostDeviceManager = (hostDeviceManager != nil ?
			hostDeviceManager : HostDeviceManager(view_controller: self))
	
		//Requests to load parts of the frontend
		server["/DragAndDrop/:path1/:path2/:path3"] = BBTHandleFrontEndRequest
		server["/DragAndDrop/:path1/:path2"] = BBTHandleFrontEndRequest
		server["/DragAndDrop/:path1"] = BBTHandleFrontEndRequest
		
		//Heartbeat
		server["/server/ping"] = {r in return .ok(.text("pong"))}
		
		hummingbirdManager.loadRequests(server: server)
		flutterManager.loadRequests(server: server)
		dataRequests!.loadRequests(server: server)
		hostDeviceManager!.loadRequests(server: server)
		soundManager.loadRequests(server: server)
		settingsManager.loadRequests(server: server)
		propertiesManager.loadRequests(server: server)
	}
	
	
	
	//MARK: WebView Delegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NSLog(navigation.description)
    }
    func webView(_ webView: WKWebView,
	decidePolicyFor navigationAction: WKNavigationAction,
	decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(WKNavigationActionPolicy.allow)
    }
    
    
    //MARK: Measure Device Shake
    //Note, this code needs to be here and not in the HostDeviceRequests file
    override var canBecomeFirstResponder : Bool {
        return true
    }
    override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        if (motion == UIEventSubtype.motionShake){
            wasShaken = true
            shakenTimer = Timer.scheduledTimer(timeInterval: TimeInterval(5),
			                                         target: self,
												   selector: #selector(ViewController.expireShake),
												   userInfo: nil,
												    repeats: false)
        }
    }
    func expireShake(){
        wasShaken = false
        shakenTimer.invalidate()
    }
    public func checkShaken() -> Bool{
        shakenTimer.invalidate()
        if wasShaken{
            wasShaken = false
            return true
        }
        return false
    }
	
	//MARK: View configuration
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
		print("Did receive memory warning")
    }
	
	override func viewWillTransition(to size: CGSize,
	                                 with coordinator: UIViewControllerTransitionCoordinator) {
		print("New size: \(size)")
		self.wv!.evaluateJavaScript("GuiElements.updateDimsPreview(\(size.width), \(size.height))",
		                            completionHandler: {print("Updated dims. Error: \($0)")})
		
		Timer.scheduledTimer(timeInterval: TimeInterval(0.5), target: self,
		                     selector: #selector(ViewController.resizePageEnd),
		                     userInfo: nil, repeats: false)

		//One day, (when we don't support iOS 9) we can schedule timers with blocks. 
//		Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { timer in
//			
//		}
	}
	
	@objc private func resizePageEnd() {
		//TODO: Switch to updateDims
		self.wv!.evaluateJavaScript("GuiElements.updateDims()",
		                            completionHandler: {print("Updated dims. Error: \($0)")})
	}


}

