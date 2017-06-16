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
		server["data/getAvailableName"] = self.availableNameRequest
        
        server["/data/save"] = saveRequest(request:)
        server["/data/load"] = loadRequest(request:)
        server["/data/rename"] = renameRequest(request:)
        server["/data/delete"] = deleteRequest(request:)
        server["/data/export"] = exportRequest(request:)
    }
	
	func availableNameRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		guard let name = queries["filename"] else {
			return .badRequest(.text("Malformed Request"))
		}
		
		//To find the reason why a name might be different
		let sanName = DataModel.sanitizedName(of: name)
		let alreadySanitized = (sanName == name)
		let alreadyAvailable = DataModel.shared.bbxNameAvailable(sanName)
		let availableName = DataModel.shared.availableName(from: name)!
		
		let json: [String : Any] = ["availableName" : availableName,
		                            "alreadySanitized" : alreadySanitized,
									"alreadyAvailable" : alreadyAvailable]
		return .ok(.json(json as AnyObject))
	}
    
    func filesRequest(request: HttpRequest) -> HttpResponse {
        let filenameList = DataModel.shared.savedBBXFiles
		let nameList = filenameList.map({$0.replacingOccurrences(of: ".bbx", with: "")})
		let bodyString = nameList.joined(separator: "\n")
		
        return .ok(.text(bodyString))
    }
    
    func saveRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
        guard let rawName = queries["filename"],
			let fileString = NSString(bytes:request.body, length: request.body.count,
			                          encoding: String.Encoding.utf8.rawValue) else {
			return .badRequest(.text("Malformed Request"))
		}
		
		var name = DataModel.sanitizedName(of: rawName)
		
		if queries["options"] == "new" {
			name = DataModel.shared.availableName(from: name)!
		}
		else {
			if queries["options"] == "soft" && !DataModel.shared.bbxNameAvailable(name) {
				return .raw(409, "Conflict", nil, nil)
			}
			guard rawName == name else {
				return .badRequest(.text("Illegal Characters in filename"))
			}
		}
		
		guard DataModel.shared.save(bbxString: fileString as String, withName: name) else {
			return .internalServerError
		}
		
		return .raw(201, "Created", ["Location" : "/data/load?filename=\(name)"]) {
					(writer) throws -> Void in
							try writer.write([UInt8](name.utf8))
				}
    }
	
    func loadRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		if let filename = queries["filename"] {
			if let fileContent = DataModel.shared.getBBXContent(byName: filename) {
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
		
		guard let oldFilename = queries["oldFilename"],
			let newFilename = queries["newFilename"] else {
			return .badRequest(.text("Malformed Request"))
		}
		
		guard DataModel.nameIsSanitary(oldFilename) && DataModel.nameIsSanitary(newFilename) else {
			return .badRequest(.text("Unsanitary parameter arguments"))
		}
		
		if queries["options"] == "soft" && !DataModel.shared.bbxNameAvailable(newFilename) {
			return .raw(409, "Conflict", nil, nil)
		}
		
		guard DataModel.shared.renameBBXFile(from: oldFilename, to: newFilename) else {
			return .internalServerError
		}
		
		return .ok(.text("File Renamed"))
	}
	
    func deleteRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		if let filename = queries["filename"] {
			if DataModel.shared.deleteBBXFile(byName: filename) {
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
		
		if let filename = queries["filename"] {
			let exportedPath = DataModel.shared.getBBXFileLoc(byName: filename)
			if  FileManager.default.fileExists(atPath: exportedPath.path) {
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
