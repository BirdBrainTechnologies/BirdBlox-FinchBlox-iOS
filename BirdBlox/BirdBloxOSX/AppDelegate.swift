//
//  AppDelegate.swift
//  BirdBloxOSX
//
//  Created by Kristina Lauwers on 10/29/18.
//  Copyright © 2018 Birdbrain Technologies LLC. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow?
    var uiLoaded = false
    
    public let tintColor = CGColor(red: 1.0, green: 137.0/255.0, blue: 64.0/255.0, alpha: 1.0)
    
    public var backendServer: BBTBackendServer
    
    override init() {
        self.backendServer = BBTBackendServer()
        super.init()
        
        self.backendServer["/ui/contentLoaded"] = { request in
            self.uiLoaded = true
            return .ok(.text("Hello webpage! I am a server."))
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSLog("BBX did finish launching on OSX.")
        
        //TODO: set a tint color here?
        /*
        //Setting the tint color
        if #available(iOS 10.0, *) {
            self.window?.tintColor = UIColor(displayP3Red: 1.0, green: 137.0/255.0, blue: 64.0/255,
                                             alpha: 1.0)
            
        } else {
            self.window?.tintColor = UIColor(red: 1.0, green: 137.0/255.0, blue: 64.0/255.0,
                                             alpha: 1.0)
        }*/
        
        //Make sure date model is working
        let _ = DataModel.shared.getSetting("foo")
        
        
        DataModel.shared.migrateFromOldSystem()
    }
    
    func applicationDidHide(_ notification: Notification) {
        let _ = FrontendCallbackCenter.shared.stopExecution() //TODO: do something with result?
        self.backendServer.stop()
    }
    
    func applicationWillUnhide(_ notification: Notification) {
        self.backendServer.start()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        NSLog("Will terminate OSX app")
        DataModel.shared.clearTempoaryDirectories()
    }

    //TODO: add the last method that is in the iOS file
}

