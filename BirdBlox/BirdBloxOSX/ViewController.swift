//
//  ViewController.swift
//  BirdBloxOSX
//
//  Created by Kristina Lauwers on 10/29/18.
//  Copyright © 2018 Birdbrain Technologies LLC. All rights reserved.
//

import Cocoa
import WebKit

class ViewController: NSViewController, WKNavigationDelegate {
    
    var webView = WKWebView()
    var webUILoaded = false
    
    let server = BBTBackendServer()
    
    var stopTimer = Timer()
    var utilTimer = Timer()
    
    //Document handling
    static let curDocNeedsNameKey = "CurrentDocumentNeedsName"
    static let curDocNameKey = "CurrentDocumentName"
    let curDocNeedsNameKey = "CurrentDocumentNeedsName"
    let curDocNameKey = "CurrentDocumentName"
    private var realDoc = BBXDocument(fileURL: URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]).appendingPathComponent("empty.bbx"))
    var document: BBXDocument {
        get {
            return self.realDoc
        }
        
        set (doc) {
            self.realDoc.close(completionHandler: nil) //Doesn't this take a while?
            self.realDoc = doc
            
            if self.webUILoaded {
                self.updateDisplayFromXML(completion: { (succeeded: Bool) in
                    // Only set this document as our document if it is valid
                    //Relies on no more requests while the js is still parsing the document
                    if succeeded {
                        //TODO: add this notification back in
                        /*
                        let notificationName = UIDocument.stateChangedNotification
                        NotificationCenter.default.addObserver(forName: notificationName,
                                                               object: self.realDoc, queue: nil,
                                                               using: { notification in
                                                                
                                                                self.handleDocumentStateChangeNotification(notification)
                        })*/
                    }
                    else {
                        doc.close(completionHandler: nil)
                    }
                })
            }
        }
    }
    
    //Server Setup
    let robotRequests = RobotRequests()
    let soundManager = SoundManager()
    let settingsManager = SettingsManager()
    let propertiesManager = PropertiesManager()
    var dataRequests: DataManager? = nil
    var hostDeviceManager: HostDeviceManager? = nil
    

    override func viewDidLoad() {
        super.viewDidLoad()

        self.addHandlersToServer(self.server)
        
        guard let appDel = NSApplication.shared.delegate as? AppDelegate else {
            return
        }
        appDel.backendServer = self.server
        
        self.server["/ui/contentLoaded"] = { request in
            
            self.webUILoaded = true
            
            if let name = UserDefaults.standard.string(forKey: self.curDocNameKey) {
                //let _ = self.openProgram(byName: name)
                if FrontendCallbackCenter.shared.setFilePreference(name) {
                    NSLog("Successfully set the filename to \(name)")
                } else {
                    NSLog("Failed to set the filename to \(name)")
                }
            } else {
                NSLog("Failed to find a current filename.")
            }
            return .ok(.text("Hello webpage! I am a server."))
        }
        
        self.server.start()
        
        //Setup webview
        //Connect native calls
        
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(self.server, name: "serverSubstitute")
        config.userContentController = contentController
        
        self.webView = WKWebView(frame: .zero, configuration: config) //TODO: is this frame right?
        
        self.webView.navigationDelegate = self
        //self.webView.contentMode = UIView.ContentMode.scaleToFill
        //self.webView.backgroundColor = UIColor.gray
        
        let htmlLoc = DataModel.shared.frontendPageLoc
        let frontLoc = DataModel.shared.frontendLoc
        
        print("pre-req")
        self.webView.loadFileURL(htmlLoc, allowingReadAccessTo: frontLoc)
        print("post-req")
        
        self.view.addSubview(self.webView)
        
        //Setup callback center
        FrontendCallbackCenter.shared.webView = webView
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    //MARK: Document Handling
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
        
        
        DispatchQueue.main.async {
            self.webView.evaluateJavaScript(js) { succeeded, error in
                if let error = error {
                    NSLog("JS exception (\(error)) while opening data. ")
                    return
                }
                
                NSLog("ran JS update XML")
                if let suc = (succeeded as? Bool) {
                    completion(suc)
                }
            }
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
                if let comp = completion {
                    comp(suc)
                }
            }
        })
        
        return true
    }
    
    private func closeCurrentProgram(completion: ((Bool) -> Void)? = nil) {
        self.document.close(completionHandler: { suc in
            UserDefaults.standard.set(nil, forKey: self.curDocNameKey)
            if let completion = completion {
                completion(suc)
            }
        })
    }
    
    
    //MARK: Setup Sever

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
        
        
        robotRequests.loadRequests(server: server)
        dataRequests!.loadRequests(server: server)
        hostDeviceManager!.loadRequests(server: server)
        soundManager.loadRequests(server: server)
        settingsManager.loadRequests(server: server)
        propertiesManager.loadRequests(server: server)
        
        
        
        self.server["/cloud/showPicker"] = { (request: HttpRequest) -> HttpResponse in
            let docTypes = [DataModel.bbxUTI, "public.xml"]
            //let picker = UIDocumentPickerViewController(documentTypes: docTypes, in: .open)
            let picker = UIDocumentPickerViewController(documentTypes: docTypes, in: .import)
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
            let queries = BBTSequentialQueryArrayToDict(request.queryParams)
            
            guard let xml = String(bytes: request.body, encoding: .utf8) else {
                return .badRequest(.text("POST body not encoded in utf8."))
            }
            
            let reqName = queries["filename"] ?? "New Program"
            
            let name = DataModel.shared.availableName(from: reqName)!
            NSLog("Created file named \(name)")
            let fileURL = DataModel.shared.getBBXFileLoc(byName: name)
            
            guard DataModel.shared.emptyCurrentDocument() else {
                return .internalServerError
            }
            
            let doc = BBXDocument(fileURL: fileURL)
            doc.currentXML = xml
            doc.save(to: fileURL, for: .forCreating, completionHandler: { succeeded in
                if succeeded {
                    //                    self.webUILoaded = false
                    print(doc.documentState)
                    self.document = doc
                    //                    self.webUILoaded = true
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
            print("Open request")
            
            guard let name = queries["filename"] else {
                return .badRequest(.text("Missing Parameters"))
            }
            
            let openBlock = {
                let _ = self.openProgram(byName: name)
                print(name)
                //                if !fileExists {
                //                    return .internalServerError
                //                }
                UserDefaults.standard.set(false, forKey: self.curDocNeedsNameKey)
                UserDefaults.standard.set(name, forKey: self.curDocNameKey)
            }
            
            if self.document.documentState == .closed {
                print("Running open block now!")
                openBlock()
            } else {
                //TODO: Actually try to close the file here? What if it is already in the process of closing?
                if #available(iOS 10.0, *) {
                    DispatchQueue.main.sync {
                        self.utilTimer = Timer.scheduledTimer(withTimeInterval: 0.75,
                                                              repeats: false,
                                                              block: { t in
                                                                if self.document.documentState == .closed {
                                                                    openBlock()
                                                                } else {
                                                                    NSLog("Unable to open file.")
                                                                }
                        })
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
        
        //TOOD: Add a file closed callback so we can get rid of these wrappers.
        // Once there is a file closed callback, no delete or rename command will happen to
        // an open file.
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
            
            let curDocName = DataModel.shared.getSetting(self.curDocNameKey)
            if type == .BirdBloxProgram && oldFilename == curDocName {
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
            
            let curDocName = DataModel.shared.getSetting(self.curDocNameKey)
            guard (filename != curDocName || (type != .BirdBloxProgram) ||
                (self.document.documentState == .closed)) else {
                    print("delete open \(filename) \(curDocName ?? "no current doc") \(type) \(self.document.documentState == .closed)")
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
        
        //TODO: Do we need the additional stop here?
        
        server["/data/markAsNamed"] = { request in
            UserDefaults.standard.set(false, forKey: self.curDocNeedsNameKey)
            return .ok(.text("set"))
        }
        
        server["/robot/showUpdateInstructions"] = { request in
            DispatchQueue.main.sync {
                let str =  "http://www.hummingbirdkit.com/learning/installing-birdblox#BurnFirmware"
                
                if let url = URL(string: str),
                    NSWorkspace.shared.open(url) {
                    print("default browser was successfully opened")
                }
                
                
            }
            return .ok(.text("Presenting webpage"))
        }
    }
    
    //TODO: Handle cloud file picking
    
    //MARK: WKNavigationDelegate methods
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        //if let lang = NSLocale.preferredLanguages.first?.prefix(2) {
        if let lang = NSLocale.preferredLanguages.first {
            //let language = String(lang)
            NSLog("Setting frontend language to \(lang)")
            if FrontendCallbackCenter.shared.setLanguage(lang) {
                NSLog("Successfully set language to \(lang)")
            }
        }
    }

}

