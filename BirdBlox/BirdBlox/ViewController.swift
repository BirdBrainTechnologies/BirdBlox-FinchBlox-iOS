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
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let main_server = MainServer()
        main_server.start()
        
        self.web_view = WKWebView(frame: self.view.frame)
        self.web_view!.navigationDelegate = self
        self.web_view!.uiDelegate = self
        self.web_view!.contentMode = UIViewContentMode.scaleAspectFit

        let req = URLRequest(url: URL(string: "http://localhost:22179/DragAndDrop/HummingbirdDragAndDrop.html")!)

        self.web_view!.load(req)
        self.view.addSubview(self.web_view!)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NSLog(navigation.description)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(WKNavigationActionPolicy.allow)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

