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
let zipPath = documentsPath.stringByAppendingPathComponent("temp.zip")
let unzipPath = documentsPath.stringByAppendingPathComponent("snap")
let lastUpdatePath = documentsPath.stringByAppendingPathComponent("log.txt")
let fileManager = NSFileManager.defaultManager()
let updateKey = "LastUpdatedSnap"

public func getUpdate(){
        let zippedData = NSData(contentsOfURL: snapURL!)!
        zippedData.writeToFile(zipPath, atomically: true)
        Main.unzipFileAtPath(zipPath, toDestination: unzipPath)
        if !fileManager.fileExistsAtPath(lastUpdatePath){
            let dict: NSDictionary = NSDictionary(object: NSDate(), forKey: updateKey)
            let newLog: NSData = NSKeyedArchiver.archivedDataWithRootObject(dict)
            fileManager.createFileAtPath(lastUpdatePath, contents: newLog, attributes: nil)
        }
        fileManager.removeItemAtPath(getSnapPath().stringByAppendingPathComponent("Examples"), error: nil)
        let cloudJS = String(contentsOfFile: getSnapPath().stringByAppendingPathComponent("cloud.js"), encoding: NSUTF8StringEncoding, error: nil)
        let localCloudJS = cloudJS?.stringByReplacingOccurrencesOfString("https://snap.apps.miosoft.com/SnapCloud", withString: "https://snap.apps.miosoft.com/SnapCloudLocal", options: NSStringCompareOptions.LiteralSearch, range: nil)
        localCloudJS?.writeToFile(getSnapPath().stringByAppendingPathComponent("cloud.js"), atomically: true, encoding: NSUTF8StringEncoding, error: nil)
        let dict: NSDictionary = NSDictionary(object: NSDate(), forKey: updateKey)
        let log: NSData = NSKeyedArchiver.archivedDataWithRootObject(dict)
        log.writeToFile(lastUpdatePath, atomically: true)
}

public func getSnapPath() -> String {
    return unzipPath.stringByAppendingPathComponent("Snap--Build-Your-Own-Blocks-master")
}

public func shouldUpdate() -> Bool{
    if !fileManager.fileExistsAtPath(zipPath){
        let dict: NSDictionary = NSDictionary(object: NSDate(), forKey: updateKey)
        let newLog: NSData = NSKeyedArchiver.archivedDataWithRootObject(dict)
        fileManager.createFileAtPath(lastUpdatePath, contents: newLog, attributes: nil)
        return true
    }
    if !fileManager.fileExistsAtPath(lastUpdatePath){
        let dict: NSDictionary = NSDictionary(object: NSDate(), forKey: updateKey)
        let newLog: NSData = NSKeyedArchiver.archivedDataWithRootObject(dict)
        fileManager.createFileAtPath(lastUpdatePath, contents: newLog, attributes: nil)
        return true
    }
    let log = NSData(contentsOfFile: lastUpdatePath)
    if (log?.length <= 0){
        return true
    }
    let dict: NSDictionary = NSKeyedUnarchiver.unarchiveObjectWithData(log!)! as! NSDictionary
    let date = dict.valueForKey(updateKey) as! NSDate
    let today = NSDate()
    if (daysBetween(date, today) > 7){
        return true
    }
    else{
        return false
    }
}

private func daysBetween(d1: NSDate, d2: NSDate) -> Int{
    let unitFlag = NSCalendarUnit.CalendarUnitDay
    let calendar: NSCalendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
    let components: NSDateComponents = calendar.components(unitFlag, fromDate: d1, toDate: d2, options: nil)
    return components.day;
}

