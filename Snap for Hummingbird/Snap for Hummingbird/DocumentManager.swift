//
//  DocumentManager.swift
//  Snap for Hummingbird
//
//  Created by birdbrain on 7/13/15.
//  Copyright (c) 2015 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation


let documentsPath: String = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)[0] as! String
//let snapURL = NSURL(string: "http://snap.berkeley.edu/snapsource/snap.zip")
let snapURL = NSURL(string: "https://github.com/jmoenig/Snap--Build-Your-Own-Blocks/archive/master.zip")
let logURL = NSURL(string: "https://raw.githubusercontent.com/jmoenig/Snap--Build-Your-Own-Blocks/master/history.txt")
let zipPath = documentsPath.stringByAppendingPathComponent("temp.zip")
let unzipPath = documentsPath.stringByAppendingPathComponent("snap")
let fileManager = NSFileManager.defaultManager()
let updateKey = "LastUpdatedSnap"

public func getUpdate(){
    let zippedData = NSData(contentsOfURL: snapURL!)!
    zippedData.writeToFile(zipPath, atomically: true)
    Main.unzipFileAtPath(zipPath, toDestination: unzipPath)
    
    let cloudJS = String(contentsOfFile: getSnapPath().stringByAppendingPathComponent("cloud.js"), encoding: NSUTF8StringEncoding, error: nil)
    var localCloudJS = cloudJS?.stringByReplacingOccurrencesOfString("https://snap.apps.miosoft.com/SnapCloud", withString: "https://snap.apps.miosoft.com/SnapCloudLocal", options: NSStringCompareOptions.LiteralSearch, range: nil)
    localCloudJS?.writeToFile(getSnapPath().stringByAppendingPathComponent("cloud.js"), atomically: true, encoding: NSUTF8StringEncoding, error: nil)
    
    let snapHTML = String(contentsOfFile: getSnapPath().stringByAppendingPathComponent("snap.html"), encoding: NSUTF8StringEncoding, error: nil)
    var tweakedSnapHTML = snapHTML?.stringByReplacingOccurrencesOfString("setInterval(loop, 1)", withString: "setInterval(loop, 1)", options: NSStringCompareOptions.LiteralSearch, range: nil)
    tweakedSnapHTML?.writeToFile(getSnapPath().stringByAppendingPathComponent("snap.html"), atomically: true, encoding: NSUTF8StringEncoding, error: nil)
    
}

public func getSnapPath() -> String {
    return unzipPath.stringByAppendingPathComponent("Snap--Build-Your-Own-Blocks-master")
}

public func shouldUpdate() -> Bool{
    if !compareHistory(){
        return true
    } else {
        cleanAudio()
        return false
    }
}

public func cleanAudio() {
    let soundsPath = getSnapPath().stringByAppendingPathComponent("Sounds")
    let soundsEnumerator = fileManager.enumeratorAtPath(soundsPath)
    var pathList: Array<String> = []
    while let element = soundsEnumerator?.nextObject() as? String {
        if element.hasSuffix("m4a"){
            pathList.append(soundsPath.stringByAppendingPathComponent(element))
        }
    }
    for path in pathList{
        fileManager.removeItemAtPath(path, error: nil)
    }
}

private func compareHistory() -> Bool{
    let newHistory = NSData(contentsOfURL: logURL!)
    let oldHistoryPath = getSnapPath().stringByAppendingPathComponent("history.txt")
    if(!fileManager.fileExistsAtPath(oldHistoryPath)){
        NSLog("nothing at old history path")
        return false
    }
    let oldHistory = NSData(contentsOfFile: oldHistoryPath)
    
    if(oldHistory?.length == newHistory?.length){
        NSLog("Files are identical")
        return true
    } else {
        NSLog(String(stringInterpolationSegment: oldHistory?.length))
        NSLog(String(stringInterpolationSegment: newHistory?.length))
        NSLog("files differ")
        return false
    }
}

public func getDocPath() -> NSString{
    return documentsPath
}