//
//  FrontendRequests.swift
//  BirdBlox
//
//  Created by birdbrain on 3/21/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import Swifter

func handleFrontEndRequest(request: HttpRequest) -> HttpResponse {
    print(request.params)
    let params = request.params

    let path1: String? = params[":path1"]
    let path2: String? = params[":path2"]
    let path3: String? = params[":path3"]
	
	
	#if DEBUG
		func addOptionalComponent(comp: String?, toPath path : URL) -> URL {
			if comp == nil || comp == ""{
				return path
			}
			else {
				return path.appendingPathComponent(comp!)
			}
		}
		
		do {
			let subDirs = try FileManager.default.contentsOfDirectory(atPath: BBTunzipPath.absoluteString)
			
			if subDirs.count == 1 {
				let dir = URL(string:BBTunzipPath.absoluteString)!.appendingPathComponent(subDirs[0])
				
				let dirurl1 = addOptionalComponent(comp: path1, toPath:dir)
				let dirurl2 = addOptionalComponent(comp: path2, toPath:dirurl1)
				let dirurl3 = addOptionalComponent(comp: path3, toPath:dirurl2)
				
//				print("Sharing item from downloaded dev frontend " + dirurl3.absoluteString)
//				
//                print("File exists: \(FileManager.default.fileExists(atPath: dirurl3.absoluteString))")
				
				return shareFile(dirurl3.absoluteString)(request)
			}
		}
		catch {
		}
		print("In DEBUG mode, can't find unzipped dev dir from git, using frontend instead.")
	#endif

    var dir = "Frontend"
    if path3 != nil && path3 != "" {
        dir = dir + "/" + path1! + "/" + path2!
        if let path = getPathOfBundleFile(filename: path3!, directory: dir) {
            print(path)
            return shareFile(path)(request)
        }
    } else if path2 != nil && path2 != "" {
        dir = dir + "/" + path1!
        if let path = getPathOfBundleFile(filename: path2!, directory: dir){
            print(path)
            return shareFile(path)(request)
        }
    } else if path1 != nil && path1 != ""{
        if let path = getPathOfBundleFile(filename: path1!, directory: dir) {
            print(path)
            return shareFile(path)(request)
        }
    }
 
    return .notFound
}
