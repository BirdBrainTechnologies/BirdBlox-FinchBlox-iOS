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
    var web_view: WKWebView?
    var wasShaken: Bool = false
    var shakenTimer: Timer = Timer()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let main_server = MainServer(view_controller: self)
        main_server.start()
        
        self.web_view = WKWebView(frame: self.view.frame)
        self.web_view!.navigationDelegate = self
        self.web_view!.uiDelegate = self
        self.web_view!.contentMode = UIViewContentMode.scaleAspectFit
		
		// Should be http://localhost:22179/DragAndDrop/HummingbirdDragAndDrop.html, currently
		// swapped out for quick javascript developement
		
		let urlstr = "https://rawgit.com/TomWildenhain/HummingbirdDragAndDrop-/dev/HummingbirdDragAndDrop.html";
		let javascriptPageURL = URL(string: urlstr.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlFragmentAllowed)!)
		let req = URLRequest(url: javascriptPageURL!)
		
        self.web_view!.load(req)
        self.view.addSubview(self.web_view!)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NSLog(navigation.description)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(WKNavigationActionPolicy.allow)
    }
    
    
    //for shake 
    //Note, this code needs to be here and not in the HostDeviceRequests file
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
    public func checkShaken() -> Bool{
        shakenTimer.invalidate()
        if wasShaken{
            wasShaken = false
            return true
        }
        return false
    }
    //end shake
    
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

