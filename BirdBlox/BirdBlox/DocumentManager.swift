//
//  DocumentManager.swift
//  BirdBlox
//
//  Created by birdbrain on 3/21/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation


let documentsPath: URL! = URL(string: NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0])
let fileManager = FileManager.default

func getPathOfBundleFile(filename: String, directory: String) -> String? {
    let mainBundle = Bundle.main
    let path_as_string = mainBundle.bundlePath + "/" + directory + "/" + filename
    if fileManager.fileExists(atPath: path_as_string){
        return path_as_string
    }
    else {
        return nil
    }
}
