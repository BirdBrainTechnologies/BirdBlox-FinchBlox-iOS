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

class BBXDocumentViewController: UIViewController, BBTWebViewController, UIDocumentPickerDelegate {
	
	let webView = WKWebView()
	var webUILoaded = false
	
	let server = BBTBackendServer()
	
	var saveTimer = Timer()
	
	override func viewDidLoad() {
		NSLog("Document View Controller viewDidLoad")
		
		super.viewDidLoad()
		
		self.view.backgroundColor = UIColor.black
		
		self.setNeedsStatusBarAppearanceUpdate()
		
		self.startTimer()
		
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
	
	func startTimer() {
		self.saveTimer = Timer.scheduledTimer(timeInterval: 0.125, target: self,
		                                      selector: #selector(self.saveTimerFired),
		                                      userInfo: nil, repeats: true)
	}
	
	func saveTimerFired() {
		if self.webUILoaded {
			self.webView.evaluateJavaScript("SaveManager.currentDoc()") { file, error in
				if let error = error {
					NSLog("Error autosaving file \(error)")
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
	
	//MARK: Document Handling
	
	private var realDoc = BBXDocument(fileURL: URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]).appendingPathComponent("empty.bbx"))
	
	private func updateDisplayFromXML(completion: @escaping ((Bool) -> Void)) {
		guard self.webUILoaded else {
			return
		}
		
		//For some reason this always opens the last document 
		let eset = CharacterSet()
		let name = self.document.localizedName.addingPercentEncoding(withAllowedCharacters: eset)!
		let xml = self.document.currentXML.addingPercentEncoding(withAllowedCharacters: eset)!
		let js = "CallbackManager.data.openData('\(name)', '\(xml)')"
		
		
		self.webView.evaluateJavaScript(js) { succeeded, error in
			if let error = error {
				NSLog("JS exception (\(error)) while opening data. ")
				return
			}
			
			if let suc = (succeeded as? Bool) {
				completion(suc)
			}
		}
	}
	
	var document: BBXDocument {
		get {
			return self.realDoc
		}
		
		set (doc) {
			self.saveTimer.invalidate()
			self.realDoc.close(completionHandler: nil)
			self.realDoc = doc
			
			if self.webUILoaded {
				self.updateDisplayFromXML(completion: { (succeeded: Bool) in
					// Only set this document as our document if it is valid
					//Relies on no more requests while the js is still parsing the document
					if succeeded {
						self.startTimer()
						
						let notificationName = NSNotification.Name.UIDocumentStateChanged
						NotificationCenter.default.addObserver(forName: notificationName,
						                                       object: self.realDoc, queue: nil,
						                                       using: { notification in
																
							self.handleDocumentStateChangeNotification(notification)
						})
					}
					else {
						doc.close(completionHandler: nil)
					}
				})
			}
		}
	}
	
	func handleDocumentStateChangeNotification(_ notification: Notification) {
		switch self.document.documentState {
		case UIDocumentState.inConflict:
			let v = NSFileVersion.unresolvedConflictVersionsOfItem(at: self.document.fileURL)
			guard let versions = v else {
				print("Invalid URL")
				return
			}
			print("Conflict. Number of conflict versions \(versions.count)")
			return
		default:
			return
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
		
		self.server["/data/showCloudPicker"] = { (request: HttpRequest) -> HttpResponse in
			let picker = UIDocumentPickerViewController(documentTypes: [DataModel.bbxUTI, "public.xml"], in: .open)
			picker.delegate = self
			
			DispatchQueue.main.sync {
				self.present(picker, animated: true, completion: nil)
			}
			
			return .ok(.text("Showing picker"))
		}
		
		self.server["/data/createNewFile"] = { (request: HttpRequest) -> HttpResponse in
			let name = DataModel.shared.availableName(from: "New Program")!
			NSLog("Created file named \(name)")
			let fileURL = DataModel.shared.getBBXFileLoc(byName: name)
			let doc = BBXDocument(fileURL: fileURL)
			doc.save(to: fileURL, for: .forCreating, completionHandler: { succeeded in
				if succeeded {
					self.document = doc
				} else {
					NSLog("Creating new document failed.")
				}
			})
			
			return .raw(201, "Created", ["Location" : "/data/load?filename=\(name)"]) {
				(writer) throws -> Void in
				try writer.write([UInt8](name.utf8))
			}
		}
		
		self.server["/data/load"] = { (request: HttpRequest) -> HttpResponse in
			let queries = BBTSequentialQueryArrayToDict(request.queryParams)
			
			if let name = queries["filename"] {
//				let fileName = DataModel.shared.availableName(from: name)!
//				let fileURL = URL(fileURLWithPath: self.docsDir).appendingPathComponent(fileName).appendingPathExtension(".bbx")
				
				let fileURL = DataModel.shared.getBBXFileLoc(byName: name)
				
				if FileManager.default.fileExists(atPath: fileURL.path) {
					let doc = BBXDocument(fileURL: fileURL)
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
	
	func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
		let doc = BBXDocument(fileURL: url)
		doc.open(completionHandler: { suc in
			print("open handler suc: \(suc)")
			if suc {
				self.document = doc
				print("State 1 (from picker): \(self.document.documentState)")
			} else {
				let docName = url.lastPathComponent
				let alert = UIAlertController(title: "Unable to Open File",
				                              message: "\(docName) is not a valid .bbx file",
											  preferredStyle: .alert)
				alert.addAction(UIAlertAction(title: "Okay", style: .default))
				
				self.present(alert, animated: true, completion: nil)
			}
		})
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
