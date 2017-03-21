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
