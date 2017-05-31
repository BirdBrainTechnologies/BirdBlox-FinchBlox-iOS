//
//  DataRequests.swift
//  BirdBlox
//
//  Created by birdbrain on 4/27/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import Swifter

class DataManager: NSObject {
    
    let view_controller: ViewController
    
    init(view_controller: ViewController){
        self.view_controller = view_controller
        super.init()
    }
    
    func loadRequests(server: BBTBackendServer){
        server["/data/files"] = filesRequest(request:)
        
        server["/data/save"] = saveRequest(request:)
        server["/data/load"] = loadRequest(request:)
        server["/data/rename"] = renameRequest(request:)
        server["/data/delete"] = deleteRequest(request:)
        server["/data/export"] = exportRequest(request:)
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
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		print("Save method: \(request.method)")
		
        if let filename = queries["filename"]?.removingPercentEncoding,
			let fileString = NSString(bytes:request.body, length: request.body.count,
			                          encoding: String.Encoding.utf8.rawValue) {
			if saveStringToFile(fileString, filename: filename) {
				return .raw(201, "Created", ["Location" : "/data/load?filename=\(filename)"]) {
					(writer) throws -> Void in
							try writer.write([UInt8]((fileString as String).utf8))
				}
			}
			else {
				return .internalServerError
			}
		}
		
        return .badRequest(.text("Malformed Request"))
    }
	
    func loadRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		if let filename = queries["filename"]?.removingPercentEncoding {
			if let fileContent = getSavedFileByName(filename) {
				return .ok(.text(fileContent as (String)))
			}
			else {
				return .notFound
			}
		}
		
		return .badRequest(.text("Malformed Request"))
    }
	
    func renameRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		if let oldFilename = queries["oldFilename"]?.removingPercentEncoding,
			let newFilename = queries["newFilename"]?.removingPercentEncoding {
			if renameFile(oldFilename, new_filename: newFilename) {
				return .ok(.text("File Renamed"))
			}
			else {
				return .internalServerError
			}
		}
		
		return .badRequest(.text("Malformed Request"))
    }
	
    func deleteRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		if let filename = queries["filename"]?.removingPercentEncoding {
			if deleteFile(filename) {
				return .ok(.text("File Deleted"))
			}
			else {
				return .internalServerError
			}
		}
		
		return .badRequest(.text("Malformed Request"))
    }
	
    func exportRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		if let filename = queries["filename"]?.removingPercentEncoding {
			if let exportedPath = getSavedFileURL(filename) {
				let url = URL(fileURLWithPath: exportedPath.path)
				let view = UIActivityViewController(activityItems: [url], applicationActivities: nil)
				view.popoverPresentationController?.sourceView = self.view_controller.view
				view.excludedActivityTypes = nil
				DispatchQueue.main.async{
					self.view_controller.present(view, animated: true, completion: nil)
				}
				return .ok(.text("Exported"))
			}
			else {
				return .internalServerError
			}
        }
		
		return .badRequest(.text("Malformed Request"))
    }
    
    
}
