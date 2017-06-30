//
//  BBXDocumentViewController.swift
//  BirdBlox
//
//  Created by Jeremy Huang on 2017-06-28.
//  Copyright © 2017年 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import UIKit
import WebKit
import Swifter

class BBXDocumentViewController: UIViewController, BBTWebViewController {
	
	let webView = WKWebView()
	var webUILoaded = false
	
	let server = BBTBackendServer()
	
	var saveTimer = Timer()
	
	private var realDoc = BBXDocument(fileURL: URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory,
	                                                                                                    .userDomainMask, true)[0]).appendingPathComponent("empty.bbx"))
	
	var document: BBXDocument {
		get {
			return self.realDoc
		}
		
		set (doc) {
			self.realDoc.close(completionHandler: nil)
			
			if self.webUILoaded {
				let eset = CharacterSet()
				let name = doc.localizedName.addingPercentEncoding(withAllowedCharacters: eset)!
				let xml = doc.currentXML.addingPercentEncoding(withAllowedCharacters: eset)!
				let js = "CallbackManager.data.openData ('\(name)', '\(xml)')"
				self.webView.evaluateJavaScript(js) {
					print("Import: \($0)")
				}
			}
			
			self.realDoc = doc
		}
	}
	
	override func viewDidLoad() {
		NSLog("Document View Controller viewDidLoad")
		
		super.viewDidLoad()
		
		self.view.backgroundColor = UIColor.black
		
		self.setNeedsStatusBarAppearanceUpdate()
		
		Timer.scheduledTimer(timeInterval: 0.125, target: self,
		                     selector: #selector(self.saveTimerFired),
		                     userInfo: nil, repeats: true)
		
		//Setup Server
		
		self.addHandlersToServer(self.server)
		
		self.server["/ui/contentLoaded"] = { request in
			self.webUILoaded = true
			print("Web UI loaded")
			return .ok(.text("Hello webpage! I am a server."))
		}
		
		self.server.start()
		
		//Setup webview
		self.webView.contentMode = UIViewContentMode.scaleToFill
		self.webView.backgroundColor = UIColor.white
		
		let urlstr = "http://localhost:22179/DragAndDrop/HummingbirdDragAndDrop.html";
		let cleanUrlStr = urlstr.addingPercentEncoding(withAllowedCharacters:
			CharacterSet.urlFragmentAllowed)!
		let javascriptPageURL = URL(string: cleanUrlStr)
		let req = URLRequest(url: javascriptPageURL!,
		                     cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalCacheData)
		self.webView.load(req)
		
		self.view.addSubview(webView)
		
		//Setup callback center
		FrontendCallbackCenter.shared.webView = webView
		
		
		NSLog("Document View Controller exiting viewDidLoad")
	}
	
	//MARK: Save Timer
	
	func saveTimerFired() {
		if self.webUILoaded {
			self.webView.evaluateJavaScript("SaveManager.currentDoc()") { file, error in
				if let error = error {
					NSLog("Error autosaving file on exit \(error)")
					return
				}
				
				guard let file: Dictionary<String, String> = file as? Dictionary<String, String> else {
					return
				}
				
				guard let content = file["data"] else {
					NSLog("Autosave Missing filename or data")
					return
				}
				
				guard self.document.documentState == .normal else {
					NSLog("Document state abnormal, abandoned edit. \(self.document.documentState)")
					return
				}
				
				self.document.currentXML = content
			}
		}
	}
	
	
	//MARK: View configuration
	override var prefersStatusBarHidden : Bool {
		if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.phone {
			return true
		}
		
		return false
	}
	
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .lightContent
	}
	
	var statusBarHeight: CGFloat {
		let barSize: CGSize = UIApplication.shared.statusBarFrame.size
		return min(barSize.width, barSize.height)
	}
	
	func barRespectingRect(from screenRect: CGRect) -> CGRect {
		let height = self.statusBarHeight
		var ss = screenRect
		ss.size.height -= height
		ss.origin.y += height
		return ss
	}
	
	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		
		var frame = self.view.bounds
		frame = self.barRespectingRect(from: frame)
		self.webView.frame = frame
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
		print("Did receive memory warning")
	}
	
	override func viewWillTransition(to size: CGSize,
	                                 with coordinator: UIViewControllerTransitionCoordinator) {
		
		let nSize = self.barRespectingRect(from: CGRect(origin: CGPoint(x: 0, y: 0),
		                                                size: size)).size
		print("New size: \(nSize)")
		
		let rsJS = "GuiElements.updateDimsPreview(\(nSize.width), \(nSize.height))"
		self.webView.evaluateJavaScript(rsJS, completionHandler: {
			print("Updated dims. Error: \($0)")
		})
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
		hostDeviceManager = (hostDeviceManager != nil ?
			hostDeviceManager : HostDeviceManager(view_controller: self))
		dataRequests = dataRequests != nil ? dataRequests :  DataManager(view_controller: self)
		
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
		
		self.server["/data/load"] = { (request: HttpRequest) -> HttpResponse in
			let queries = BBTSequentialQueryArrayToDict(request.queryParams)
			
			if let name = queries["filename"] {
//				let fileName = DataModel.shared.availableName(from: name)!
//				let fileURL = URL(fileURLWithPath: self.docsDir).appendingPathComponent(fileName).appendingPathExtension(".bbx")
				
				let fileURL = DataModel.shared.getBBXFileLoc(byName: name)
				print(fileURL)
				
				if FileManager.default.fileExists(atPath: fileURL.path) {
					let doc = BBXDocument(fileURL: DataModel.shared.getBBXFileLoc(byName: name))
					doc.open(completionHandler: {suc in
						print("open handler suc: \(suc)")
						if suc {
							self.document = doc
							print("State 1: \(self.document.documentState)")
						}
					})
					
					print("State 2: \(self.document.documentState)")
					print("State 3: \(doc.documentState)")
				}
				else {
					print("File does not exist")
				}
			}
			
			return .ok(.text(""))
		}
		
		self.server["/data/save"] = { (request: HttpRequest) in
			return HttpResponse.ok(.text("Using UIDocument Autosave instead"))
		}
	}
	
	//BBTWebViewController
	var wv: WKWebView {
		return self.webView
	}
}

protocol BBTWebViewController {
	var wv: WKWebView { get }
	var webUILoaded: Bool { get }
	
	
	//MARK: UIViewController methods that we need
	var view: UIView! { get set }
	
	func present(_ viewControllerToPresent: UIViewController,
	             animated flag: Bool, completion: (() -> Void)?)
}
