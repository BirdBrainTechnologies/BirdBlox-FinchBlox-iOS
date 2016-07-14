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

public func saveStringToFile(string: NSString, fileName: String) -> Bool{
    let fullFileName = fileName + ".xml"
    let isDir: UnsafeMutablePointer<ObjCBool> = nil
    if(!fileManager.fileExistsAtPath(getSavePath().path!, isDirectory: isDir)) {
        do {
        try fileManager.createDirectoryAtPath(getSavePath().path!, withIntermediateDirectories: false, attributes: nil)
        }
        catch {
            NSLog("Failed to create save directory")
        }
    }
    
    let path = getSavePath().URLByAppendingPathComponent(fullFileName).path!
    do {
        //fileManager.createFileAtPath(path, contents: nil, attributes: nil)
        try string.writeToFile(path, atomically: true, encoding: NSUTF8StringEncoding)
        NSLog("Wrote " + (string as String) + " to file")
        NSLog("return true")
        return true
    }
    catch {
        NSLog("return false: \(error)")
        return false
    }
}

public func getSavedFileNames() -> [String]{
    do {
        let paths = try fileManager.contentsOfDirectoryAtPath(getSavePath().path!)
        let paths2 = paths.map({ (string) -> String in
            return string.stringByReplacingOccurrencesOfString(".xml", withString: "")
        })
        return paths2
    } catch {
        return []
    }
}

public func getSavePath() -> NSURL{
    return getDocPath().URLByAppendingPathComponent("SavedFiles")
}

public func getSavedFileByName(fileName: String) -> NSString {
    do {
        let fullFileName = fileName + ".xml"
        let path = getSavePath().URLByAppendingPathComponent(fullFileName).path!
        let file: NSString = try NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding)
        return file
    } catch {
        return "File not found"
    }
}

public func deleteFile(fileName: String) -> Bool {
    let fullFileName = fileName + ".xml"
    let path = getSavePath().URLByAppendingPathComponent(fullFileName).path!
    do {
        try fileManager.removeItemAtPath(path)
        return true
    } catch {
        return false
    }
}

public func renameFile(startFileName: String, newFileName: String) -> Bool {
    let startFullFileName = startFileName + ".xml"
    let startPath = getSavePath().URLByAppendingPathComponent(startFullFileName).path!
    let newFullFileName = newFileName + ".xml"
    let newPath = getSavePath().URLByAppendingPathComponent(newFullFileName).path!
    do {
        try fileManager.moveItemAtPath(startPath, toPath: newPath)
        return true
    } catch {
        return false
    }
}

public func getDocPath() -> NSURL{
    return documentsPath
}