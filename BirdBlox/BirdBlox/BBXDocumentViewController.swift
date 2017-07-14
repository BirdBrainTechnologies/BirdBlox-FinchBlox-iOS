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
	
//	var saveTimer = Timer()
	
	override func viewDidLoad() {
		NSLog("Document View Controller viewDidLoad")
		
		super.viewDidLoad()
		
		self.view.backgroundColor = UIColor.black
		
		self.setNeedsStatusBarAppearanceUpdate()
		
		//Setup Server
		
		FrontendCallbackCenter.shared.webView = webView
		
		self.addHandlersToServer(self.server)
		
		(UIApplication.shared.delegate as! AppDelegate).backendServer = self.server
		
		self.server["/ui/contentLoaded"] = { request in
			self.webUILoaded = true
			
			if let name = UserDefaults.standard.string(forKey: self.curDocNameKey) {
				let _ = self.openProgram(byName: name)
			}
			
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
		print("pre-req")
		self.webView.load(req)
		print("post-req")
		
		self.view.addSubview(webView)
		
		//Setup callback center
		FrontendCallbackCenter.shared.webView = webView
		
		NSLog("Document View Controller exiting viewDidLoad")
	}
	
	//MARK: Save Timer
	
/*	func startTimer() {
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
	} */
	
	//MARK: Document Handling
	static let curDocNeedsNameKey = "CurrentDocumentNeedsName"
	static let curDocNameKey = "CurrentDocumentName"
	let curDocNeedsNameKey = "CurrentDocumentNeedsName"
	let curDocNameKey = "CurrentDocumentName"
	
	private var realDoc = BBXDocument(fileURL: URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]).appendingPathComponent("empty.bbx"))
	
	private func updateDisplayFromXML(completion: @escaping ((Bool) -> Void)) {
		guard self.webUILoaded else {
			return
		}
		
		//For some reason this always opens the last document 
		let eset = CharacterSet()
		let name = self.document.localizedName.addingPercentEncoding(withAllowedCharacters: eset)!
		let xml = self.document.currentXML.addingPercentEncoding(withAllowedCharacters: eset)!
		let needsName = UserDefaults.standard.bool(forKey: self.curDocNeedsNameKey)
		let js = "CallbackManager.data.open('\(name)', '\(xml)', \(!needsName))"
		
		
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
			self.realDoc.close(completionHandler: nil)
			self.realDoc = doc
			
			if self.webUILoaded {
				self.updateDisplayFromXML(completion: { (succeeded: Bool) in
					// Only set this document as our document if it is valid
					//Relies on no more requests while the js is still parsing the document
					if succeeded {
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
	
	//Returns false if no program by that name exists
	private func openProgram(byName name: String, completion: ((Bool) -> Void)? = nil) -> Bool {
		let fileURL = DataModel.shared.getBBXFileLoc(byName: name)
		
		guard FileManager.default.fileExists(atPath: fileURL.path) else {
			NSLog("Asked to open file that does not exist.")
			return false
		}
		
		let doc = BBXDocument(fileURL: fileURL)
		doc.open(completionHandler: {suc in
			print("open handler suc: \(suc)")
			if suc {
				self.document = doc
			}
			
			if let comp = completion {
				comp(suc)
			}
		})
		
		return true
	}
	
	private func closeCurrentProgram(completion: ((Bool) -> Void)? = nil) {
		self.document.close(completionHandler: { suc in
			if let completion = completion {
				completion(suc)
			}
		})
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
	
	//Shaken Sensor
	var timeLastShaken = Date(timeIntervalSince1970: 0)
	var shakeExpireInterval = TimeInterval(5) //seconds
	
	override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
		if motion == .motionShake {
			self.timeLastShaken = Date(timeIntervalSinceNow: 0)
		}
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
		
		self.server["/tablet/shake"] = { (request: HttpRequest) -> HttpResponse in
			let interval = Date(timeIntervalSinceNow: 0).timeIntervalSince(self.timeLastShaken)
			let respStr = (interval < self.shakeExpireInterval) ? "1" : "0"
			self.timeLastShaken = Date(timeIntervalSince1970: 0)
			return .ok(.text(respStr))
		}
		
		self.server["/data/showCloudPicker"] = { (request: HttpRequest) -> HttpResponse in
			let picker = UIDocumentPickerViewController(documentTypes: [DataModel.bbxUTI, "public.xml"], in: .open)
			picker.delegate = self
			
			DispatchQueue.main.sync {
				self.present(picker, animated: true, completion: nil)
			}
			
			return .ok(.text("Showing picker"))
		}
		
		self.server["/data/close"] = { (request: HttpRequest) -> HttpResponse in
			self.closeCurrentProgram()
			return .ok(.text(""))
		}
		
		self.server["/data/new"] = { (request: HttpRequest) -> HttpResponse in
			guard let xml = String(bytes: request.body, encoding: .utf8) else {
				return .badRequest(.text("POST body not encoded in utf8."))
			}
			
			let name = DataModel.shared.availableName(from: "New Program")!
			NSLog("Created file named \(name)")
			let fileURL = DataModel.shared.getBBXFileLoc(byName: name)
			
			guard DataModel.shared.emptyCurrentDocument() else {
				return .internalServerError
			}
			
			let doc = BBXDocument(fileURL: fileURL)
			doc.currentXML = xml
			doc.save(to: fileURL, for: .forCreating, completionHandler: { succeeded in
				if succeeded {
//					self.webUILoaded = false
					print(doc.documentState)
					self.document = doc
//					self.webUILoaded = true
					let _ = FrontendCallbackCenter.shared.documentSetName(name: name)
				} else {
					NSLog("Creating new document failed.")
				}
			})
			
			UserDefaults.standard.set(true, forKey: self.curDocNeedsNameKey)
			UserDefaults.standard.set(name, forKey: self.curDocNameKey)
			
			return .raw(201, "Created", ["Location" : "/data/load?filename=\(name)"]) {
				(writer) throws -> Void in
				try writer.write([UInt8](name.utf8))
			}
		}
		
		self.server["/data/open"] = { (request: HttpRequest) -> HttpResponse in
			let queries = BBTSequentialQueryArrayToDict(request.queryParams)
			
			guard let name = queries["filename"] else {
				return .badRequest(.text("Missing Parameters"))
			}
			
			let openBlock = {
				let _ = self.openProgram(byName: name)
				print(name)
//				if !fileExists {
//					return .internalServerError
//				}
				UserDefaults.standard.set(false, forKey: self.curDocNeedsNameKey)
				UserDefaults.standard.set(name, forKey: self.curDocNameKey)
			}
			
			if self.document.documentState == .closed {
				openBlock()
			} else {
				self.closeCurrentProgram() { suc in
					if suc {
						openBlock()
					}
				}
			}
			
				return .ok(.text(""))
		}
		
		
		self.server["/data/save"] = { (request: HttpRequest) in
			return HttpResponse.ok(.text("Using UIDocument Autosave instead"))
		}
		
		self.server["/data/autoSave"] = { (request: HttpRequest) -> HttpResponse in
			guard let xml = String(bytes: request.body, encoding: .utf8) else {
				return .badRequest(.text("POST body not encoded in utf8."))
			}
			
			self.document.currentXML = xml
			
			return .ok(.text("Success"))
		}
		
		let renameHandler = self.dataRequests!.renameRequest
		self.server["/data/rename"] = { (request: HttpRequest) -> HttpResponse in
			let queries = BBTSequentialQueryArrayToDict(request.queryParams)
			
			guard let typeStr = queries["type"],
				let newFilename = queries["newFilename"],
				let oldFilename = queries["oldFilename"] else {
					return .badRequest(.text("Missing Parameters"))
			}
			guard let type = self.dataRequests?.fileType(fromParameter: typeStr) else {
				return .badRequest(.text("Invalid type argument"))
			}
			
			if type == .BirdBloxProgram && oldFilename == self.document.localizedName {
				self.closeCurrentProgram(completion: { suc in
					if !suc {
						NSLog("Unable to close current document for renaming")
						return
					}
					
					let resp = renameHandler(request)
					
					switch (resp) {
					case .ok(_):
						self.webView.evaluateJavaScript("CallbackManager.data.filesChanged()") {
							result, error in
							UserDefaults.standard.set(newFilename, forKey: self.curDocNameKey)
							UserDefaults.standard.set(false, forKey: self.curDocNeedsNameKey)
							let _ = self.openProgram(byName: newFilename)
						}
					default:
						self.webView.evaluateJavaScript("CallbackManager.data.close()")
						return
					}
				})
				
				return .ok(.text("We'll see"))
			}
			else {
				return renameHandler(request)
			}
		}
		
		let deleteHandler = self.dataRequests!.deleteRequest
		self.server["/data/delete"] = { (request: HttpRequest) -> HttpResponse in
			let queries = BBTSequentialQueryArrayToDict(request.queryParams)
			guard let filename = queries["filename"],
				let typeStr = queries["type"] else {
					return .badRequest(.text("Missing Parameters"))
			}
			guard let type = self.dataRequests?.fileType(fromParameter: typeStr) else {
				return .badRequest(.text("Invalid type argument"))
			}
			
			guard (filename != self.document.localizedName || (type != .BirdBloxProgram) ||
				(self.document.documentState == .closed)) else {
				print("delete open")
				self.closeCurrentProgram(completion: { suc in
					if suc {
						let _ = deleteHandler(request)
						self.wv.evaluateJavaScript("CallbackManager.data.close()")
						self.wv.evaluateJavaScript("CallbackManager.data.filesChanged()")
					}
				})
				return .ok(.text("We'll see"))
			}
			
			return deleteHandler(request)
		}
	}
	
	func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
		let doc = BBXDocument(fileURL: url)
		doc.open(completionHandler: { suc in
			print("open handler suc: \(suc)")
			if suc {
				self.document = doc
				print("State 1 (from picker): \(self.document.documentState)")
				
				UserDefaults.standard.set(nil, forKey: self.curDocNameKey)
				UserDefaults.standard.set(nil, forKey: self.curDocNeedsNameKey)
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
	
	
	//MARK: Convinience
	
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
