//
//  DataRequests.swift
//  BirdBlox
//
//  Created by birdbrain on 4/27/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import Swifter

class DataRequests: NSObject {
    
    let view_controller: ViewController
    
    init(view_controller: ViewController){
        self.view_controller = view_controller
        super.init()
    }
    
    func loadRequests(server: inout HttpServer){
        server["/data/files"] = filesRequest(request:)
        
        server["/data/save/:filename/"] = saveRequest(request:)
        server["/data/load/:filename/"] = loadRequest(request:)
        server["/data/rename/:old_filename/:new_filename"] = renameRequest(request:)
        server["/data/delete/:filename/"] = deleteRequest(request:)
        server["/data/export/:filename/"] = exportRequest(request:)


    
        //TODO: This is hacky. For some reason, some requests don't
        // want to be pattern matched to properly
        let old_handler = server.notFoundHandler
        server.notFoundHandler = {
            r in
            if r.path == "/data/files" {
                return self.filesRequest(request: r)
            }
            if let handler = old_handler{
                return handler(r)
            } else {
                return .notFound
            }
        }
    }
    
    func filesRequest(request: HttpRequest) -> HttpResponse {
        let fileList = getSavedFileNames()
        var files: String = "";
        fileList.forEach({ (string) in
            files.append(string)
            files.append("\n")
        })
        return .ok(.text(files))
    }
    
    func saveRequest(request: HttpRequest) -> HttpResponse {
        let filename = (request.params[":filename"]?.removingPercentEncoding)!
        let requestForms = request.parseUrlencodedForm()
        var body: String? = nil
        for form in requestForms {
            if form.0 == "data" {
                body = form.1
                break
            }
        }
        if let requestBody = body {
            let xml: String = requestBody.replacingOccurrences(of: "data=", with: "")
            if saveStringToFile(xml as NSString, filename: filename) {
                return .ok(.text("Saved"))
            }
        }
        return .ok(.text("Failed"))
    }
    func loadRequest(request: HttpRequest) -> HttpResponse {
        let filename = request.params[":filename"]?.removingPercentEncoding
        let fileContent = getSavedFileByName(filename!)
        if (fileContent == "File not found") {
            return .ok(.text("Failed"))
        }
        return .ok(.text(fileContent as (String)))
    }
    func renameRequest(request: HttpRequest) -> HttpResponse {
        let filename = (request.params[":old_filename"]?.removingPercentEncoding)!
        let new_filename = (request.params[":new_filename"]?.removingPercentEncoding)!
        
        let result = renameFile(filename, new_filename: new_filename)
        if (result == false) {
            return .ok(.text("Failed"))
        }
        return .ok(.text("File Renamed"))
    }
    func deleteRequest(request: HttpRequest) -> HttpResponse {
        let filename = request.params[":filename"]?.removingPercentEncoding
        let result = deleteFile(filename!)
        if (result == false) {
            return .ok(.text("Failed"))
        }
        return .ok(.text("File Deleted"))
    }
    func exportRequest(request: HttpRequest) -> HttpResponse {
        let filename = (request.params[":filename"]?.removingPercentEncoding)!
        let requestForms = request.parseUrlencodedForm()
        var body: String? = nil
        for form in requestForms {
            if form.0 == "data" {
                body = form.1
                break
            }
        }
        if let requestBody = body {
            let xml: String = requestBody.replacingOccurrences(of: "data=", with: "")
            if saveStringToFile(xml as NSString, filename: filename) {
                let exportedPath = getSavedFileURL(filename)
                let url = URL(fileURLWithPath: exportedPath.path)
                let view = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                view.popoverPresentationController?.sourceView = self.view_controller.view
                view.excludedActivityTypes = nil
                DispatchQueue.main.async{
                    self.view_controller.present(view, animated: true, completion: nil)
                }
                return .ok(.text("Exported"))
            }
        }
        return .ok(.text("Failed"))
    }
    
    
}
