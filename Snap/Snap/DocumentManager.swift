//
//  DocumentManager.swift
//  Snap
//
//  Created by birdbrain on 7/13/15.
//  Copyright (c) 2015 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation


let documentsPath: NSURL! = NSURL(string: NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)[0])

let snapURL = NSURL(string: "https://github.com/jmoenig/Snap--Build-Your-Own-Blocks/archive/master.zip")
let logURL = NSURL(string: "https://raw.githubusercontent.com/jmoenig/Snap--Build-Your-Own-Blocks/master/history.txt")
let zipPath = documentsPath.URLByAppendingPathComponent("temp.zip")
let unzipPath = documentsPath.URLByAppendingPathComponent("snap")
let fileManager = NSFileManager.defaultManager()
let updateKey = "LastUpdatedSnap"

let soundsFilePath = getSnapPath().URLByAppendingPathComponent("Sounds/SOUNDS").path!
let soundsFileBakPath = getSnapPath().URLByAppendingPathComponent("Sounds/SOUNDS.bak").path!


public func getUpdate(){
    let zippedData = NSData(contentsOfURL: snapURL!)!
    zippedData.writeToFile(zipPath.path!, atomically: true)
    Main.unzipFileAtPath(zipPath.path!, toDestination: unzipPath.path!)
    do{
        let cloudJS = try String(contentsOfFile: getSnapPath().URLByAppendingPathComponent("cloud.js").path!, encoding: NSUTF8StringEncoding)
        let localCloudJS = cloudJS.stringByReplacingOccurrencesOfString("https://snap.apps.miosoft.com/SnapCloud", withString: "https://snap.apps.miosoft.com/SnapCloudLocal", options: NSStringCompareOptions.LiteralSearch, range: nil)
        try localCloudJS.writeToFile(getSnapPath().URLByAppendingPathComponent("cloud.js").path!, atomically: true, encoding: NSUTF8StringEncoding)
        let snapHTML = try String(contentsOfFile: getSnapPath().URLByAppendingPathComponent("snap.html").path!, encoding: NSUTF8StringEncoding)
        let tweakedSnapHTML = snapHTML.stringByReplacingOccurrencesOfString("setInterval(loop, 1)", withString: "setInterval(loop, 1)", options: NSStringCompareOptions.LiteralSearch, range: nil)
        try tweakedSnapHTML.writeToFile(getSnapPath().URLByAppendingPathComponent("snap.html").path!, atomically: true, encoding: NSUTF8StringEncoding)
        let guiJS = try String(contentsOfFile: getSnapPath().URLByAppendingPathComponent("gui.js").path!, encoding: NSUTF8StringEncoding)
        var dataSaveGuiJS = guiJS.stringByReplacingOccurrencesOfString("this.saveXMLAs(str, name, newWindow);", withString: "window.open(dataPrefix + encodeURIComponent(str));", options: NSStringCompareOptions.LiteralSearch, range: nil)
        dataSaveGuiJS = dataSaveGuiJS.stringByReplacingOccurrencesOfString("'data:text/' + plain ? 'plain,' : 'xml,'", withString: "'data:text/xml,'", options: NSStringCompareOptions.LiteralSearch, range: nil)
        try dataSaveGuiJS.writeToFile(getSnapPath().URLByAppendingPathComponent("gui.js").path!, atomically: true, encoding: NSUTF8StringEncoding)
    }
    catch{
        print("Error: Cannot update. Some error has occured downloading update\n");
    }
}

public func getSnapPath() -> NSURL {
    return unzipPath.URLByAppendingPathComponent("Snap--Build-Your-Own-Blocks-master")
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
    let soundsPath = getSnapPath().URLByAppendingPathComponent("Sounds")
    let soundsEnumerator = fileManager.enumeratorAtPath(soundsPath.path!)
    var pathList: Array<String> = []
    if (fileManager.fileExistsAtPath(soundsFileBakPath)) {
        do {
            let soundsBakFile = try String(contentsOfFile: soundsFileBakPath, encoding: NSUTF8StringEncoding)
            try soundsBakFile.writeToFile(soundsFilePath, atomically: true, encoding: NSUTF8StringEncoding)
        } catch {
            print("Error: Could not delete some audio file\n")
        }
    }
    while let element = soundsEnumerator?.nextObject() as? String {
        if element.hasSuffix("m4a"){
            pathList.append(soundsPath.URLByAppendingPathComponent(element).path!)
        }
    }
    for path in pathList{
        do{
            try fileManager.removeItemAtPath(path)
        } catch {
            print("Error: Could not delete some audio file\n")
        }
    }
}

public func addToSoundsFile(filename: String) {
    do {
        if (!fileManager.fileExistsAtPath(soundsFileBakPath)) {
            let soundsBakFile = try String(contentsOfFile: soundsFilePath, encoding: NSUTF8StringEncoding)
            try soundsBakFile.writeToFile(soundsFileBakPath, atomically: true, encoding: NSUTF8StringEncoding)
        }
        var soundsFile = try String(contentsOfFile: soundsFilePath, encoding: NSUTF8StringEncoding)
        soundsFile = soundsFile.stringByAppendingString(filename + "\t" + filename.characters.split{$0 == "."}.map(String.init)[0] + "\n")
        try soundsFile.writeToFile(soundsFilePath, atomically: true, encoding: NSUTF8StringEncoding)
    } catch {
        print ("Failed to add new sound\n")
    }
}


private func compareHistory() -> Bool{
    let newHistory = NSData(contentsOfURL: logURL!)
    let oldHistoryPath = getSnapPath().URLByAppendingPathComponent("history.txt")
    if(!fileManager.fileExistsAtPath(oldHistoryPath.path!)){
        NSLog("nothing at old history path")
        return false
    }
    let oldHistory = NSData(contentsOfFile: oldHistoryPath.path!)
    
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

public func getDocPath() -> NSURL{
    return documentsPath
}