//
//  AppDelegate.swift
//  BirdBlox
//
//  Created by birdbrain on 3/21/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
	var uiLoaded = false
	
	public let tintColor = UIColor(red: 1.0, green: 137.0/255.0, blue: 64.0/255.0, alpha: 1.0)
	
	public var backendServer: BBTBackendServer
	
	override init() {
		self.backendServer = BBTBackendServer()
		super.init()
		
		self.backendServer["/ui/contentLoaded"] = { request in
			self.uiLoaded = true
			return .ok(.text("Hello webpage! I am a server."))
		}
	}
    
	/*
    private func autoSave(successCompletion: ((Void) -> Void)? = nil) {
        guard self.uiLoaded else {
			print("UI not loaded so not autosaving")
            return
        }
        
        guard let vc = self.window?.rootViewController as? ViewController else {
            return
        }
        
        vc.wv.evaluateJavaScript("SaveManager.currentDoc();") { file, error in
            if let error = error {
                NSLog("Error autosaving file on exit \(error)")
                return
            }
            
            guard let file: Dictionary<String, String> = file as? Dictionary<String, String> else {
                return
            }
            
            guard let filename = file["filename"],
                let content = file["data"] else {
                    NSLog("Autosave Missing filename or data")
                    return
            }
            
            let suc = DataModel.shared.save(bbxString: content, withName: filename)
            NSLog("Attempted to auto save " + filename + " on exit with success \(suc).")
            if suc && successCompletion != nil {
                successCompletion!()
            }
        }
    }
	*/


    func application(_ application: UIApplication,
		didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool{
        // Override point for customization after application launch.
		
		NSLog("BBX Did finish launching")
		
		//Setting the tint color
		if #available(iOS 10.0, *) {
			self.window?.tintColor = UIColor(displayP3Red: 1.0, green: 137.0/255.0, blue: 64.0/255,
			                                 alpha: 1.0)
		} else {
			self.window?.tintColor = UIColor(red: 1.0, green: 137.0/255.0, blue: 64.0/255.0,
			                                 alpha: 1.0)
		}
		
		//Make sure date model is working
		let _ = DataModel.shared.getSetting("foo")
		
		
		DataModel.shared.migrateFromOldSystem()
		
		//Already opens documents when closed without this.
//		if let los = launchOptions,
//			let url = los[.url] as? URL {
//			return self.application(application, open: url)
//		}
        
        /*
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"
        dateFormatter.timeZone = TimeZone.current
        //redirect sterr (which includes NSLog) to a log file in the app's documents directory
        var paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        print("Documents directory: \(documentsDirectory)")
        let logFile = "\(dateFormatter.string(from: Date())).log"
        let logFilePath = (documentsDirectory as NSString).appendingPathComponent(logFile)
        freopen(logFilePath.cString(using: String.Encoding.ascii)!, "a+", stderr)
        */
		
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
		
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
		
        let _ = FrontendCallbackCenter.shared.stopExecution() //TODO: do something with result?
		self.backendServer.stop()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
		self.backendServer.start()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
		NSLog("Will terminate")
		DataModel.shared.clearTempoaryDirectories()
    }
	
	func application(_ app: UIApplication, open url: URL,
	                 options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
		
		defer {
			do {
				//let inboxLoc = DataModel.shared.documentLoc.appendingPathComponent("Inbox")
				print("trying to delete \(url)")
				try FileManager.default.removeItem(at: url)
			} catch {
				NSLog("Unable to delete temp file")
			}
		}
		
		print("Import starting")
		
		do {
			//let name = url.lastPathComponent.replacingOccurrences(of: ".bbx", with: "") + "_import"
			let name = url.lastPathComponent.replacingOccurrences(of: ".bbx", with: "")
			
            guard let avname = DataModel.shared.availableName(from: name) else { //This also sanitizes the name
                return false
            }
			let toLocation =  DataModel.shared.fileLocation(forName: avname, type: .BirdBloxProgram)
			print("\(toLocation)")
			try FileManager.default.copyItem(at: url, to: toLocation)
			print("location written to")
			
			UserDefaults.standard.set(false, forKey: BBXDocumentViewController.curDocNeedsNameKey)
			UserDefaults.standard.set(avname, forKey: BBXDocumentViewController.curDocNameKey)
			
			guard let safeName = avname.addingPercentEncoding(withAllowedCharacters: CharacterSet()) else{
				return false
			}
			print(safeName)
            let openBlock = {
                let req = "data/open?filename=\(safeName)"
                let _ = FrontendCallbackCenter.shared.echo(getRequestString: req)
                //TODO: Are the next 2 lines necessary?
                DataModel.shared.addSetting("currentDoc", value: avname)
                DataModel.shared.addSetting("currentDocNamed", value: "true")
            }
            if let vc = self.window?.rootViewController as? BBXDocumentViewController {
                if vc.document.documentState == .closed {
                    openBlock()
                } else {
                    vc.document.close(completionHandler: { suc in
                        if suc { openBlock() }
                    })
                }
            }
			
		} catch {
			NSLog("I'm unable to open the imported file")
			return false
		}
		
		return true
	}

}

