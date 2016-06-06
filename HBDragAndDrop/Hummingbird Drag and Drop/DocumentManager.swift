//
//  DocumentManager.swift
//  Snap for Hummingbird
//
//  Created by birdbrain on 7/13/15.
//  Copyright (c) 2015 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation


let documentsPath: NSURL! = NSURL(string: NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)[0])
let repoUrl = NSURL(string: "https://github.com/BirdBrainTechnologies/HummingbirdDragAndDrop-/archive/master.zip")
let logURL = NSURL(string: "https://raw.githubusercontent.com/BirdBrainTechnologies/HummingbirdDragAndDrop-/master/version.txt")
let zipPath = documentsPath.URLByAppendingPathComponent("temp.zip")
let unzipPath = documentsPath.URLByAppendingPathComponent("DragAndDrop")
let fileManager = NSFileManager.defaultManager()

public func getUpdate(){
    let zippedData = NSData(contentsOfURL: repoUrl!)!
    zippedData.writeToFile(zipPath.path!, atomically: true)
    Main.unzipFileAtPath(zipPath.path!, toDestination: unzipPath.path!)
}

public func getPath() -> NSURL {
    return unzipPath.URLByAppendingPathComponent("HummingbirdDragAndDrop--master")
}

public func shouldUpdate() -> Bool{
    return !compareHistory()
}

private func compareHistory() -> Bool{
    let newHistory = NSData(contentsOfURL: logURL!)
    let oldHistoryPath = getPath().URLByAppendingPathComponent("version.txt")
    if(!fileManager.fileExistsAtPath(oldHistoryPath.path!)){
        NSLog("nothing at old history path")
        return false
    }
    let oldHistory = NSData(contentsOfFile: oldHistoryPath.path!)
    
    if(oldHistory == newHistory){
        NSLog("History files are identical")
        return true
    } else {
        NSLog(String(stringInterpolationSegment: oldHistory?.length))
        NSLog(String(stringInterpolationSegment: newHistory?.length))
        NSLog("History files differ")
        return false
    }
}

public func getDocPath() -> NSURL{
    return documentsPath
}