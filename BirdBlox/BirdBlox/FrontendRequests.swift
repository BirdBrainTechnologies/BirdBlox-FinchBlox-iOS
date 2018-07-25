//
//  FrontendRequests.swift
//  BirdBlox
//
//  Created by birdbrain on 3/21/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
//import Swifter

func BBTHandleFrontEndRequest(request: HttpRequest) -> HttpResponse {
    let params = request.params

    let path1: String? = params[":path1"]
    let path2: String? = params[":path2"]
    let path3: String? = params[":path3"]
	

	func addOptionalComponent(comp: String?, toPath path : URL) -> URL {
		if comp == nil || comp == ""{
			return path
		}
		else {
			return path.appendingPathComponent(comp!)
		}
	}
	
	let dir = DataModel.shared.frontendLoc
	print(dir.path)
	
	let dirurl1 = addOptionalComponent(comp: path1, toPath:dir)
	let dirurl2 = addOptionalComponent(comp: path2, toPath:dirurl1)
	let dirurl3 = addOptionalComponent(comp: path3, toPath:dirurl2)
	
//				print("Sharing item from downloaded dev frontend " + dirurl3.absoluteString)
//				
//                print("File exists: \(FileManager.default.fileExists(atPath: dirurl3.absoluteString))")
	
	guard FileManager.default.fileExists(atPath: dirurl3.absoluteString) else {
		NSLog("Unable to find \(dirurl3.absoluteString)")
		return .notFound
	}
	
	NSLog("Serving frontend resource \(dirurl3.absoluteString)")
	return shareFile(dirurl3.absoluteString)(request)
}
