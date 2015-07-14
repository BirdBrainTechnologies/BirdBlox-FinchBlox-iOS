//
//  DocumentManager.swift
//  Snap for Hummingbird
//
//  Created by birdbrain on 7/13/15.
//  Copyright (c) 2015 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation


let documentsPath: String = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)[0] as! String
let snapURL = NSURL(string: "http://snap.berkeley.edu/snapsource/snap.zip")
let zipPath = documentsPath.stringByAppendingPathComponent("temp.zip")
let unzipPath = documentsPath.stringByAppendingPathComponent("snap")
let lastUpdatePath = documentsPath.stringByAppendingPathComponent("log.txt")
let fileManager = NSFileManager.defaultManager()
let updateKey = "LastUpdatedSnap"

public func getUpdate(){
        println("pulling zip")
        let zippedData = NSData(contentsOfURL: snapURL!)!
        println("writing zip")
        zippedData.writeToFile(zipPath, atomically: true)
        println("unzipping")
        Main.unzipFileAtPath(zipPath, toDestination: unzipPath)
        if !fileManager.fileExistsAtPath(lastUpdatePath){
            println("making new log file")
            let dict: NSDictionary = NSDictionary(object: NSDate(), forKey: updateKey)
            let newLog: NSData = NSKeyedArchiver.archivedDataWithRootObject(dict)
            fileManager.createFileAtPath(lastUpdatePath, contents: newLog, attributes: nil)
        }
        println("updating log")
        let dict: NSDictionary = NSDictionary(object: NSDate(), forKey: updateKey)
        let log: NSData = NSKeyedArchiver.archivedDataWithRootObject(dict)
        println("set log")
        log.writeToFile(lastUpdatePath, atomically: true)
        println("wrote log")
}

public func getSnapPath() -> String {
    let enumerator: NSDirectoryEnumerator = fileManager.enumeratorAtPath(unzipPath)!
    while let element = enumerator.nextObject() as? String{
        println(element)
    }
    return unzipPath
}

public func shouldUpdate() -> Bool{
    println("Should update?")
    if !fileManager.fileExistsAtPath(zipPath){
        println("no zip");
        let dict: NSDictionary = NSDictionary(object: NSDate(), forKey: updateKey)
        let newLog: NSData = NSKeyedArchiver.archivedDataWithRootObject(dict)
        println("to create new log")
        fileManager.createFileAtPath(lastUpdatePath, contents: newLog, attributes: nil)
        println("created new log")
        return true
    }
    println("isZip")
    if !fileManager.fileExistsAtPath(lastUpdatePath){
        println("should update yes!")
        let dict: NSDictionary = NSDictionary(object: NSDate(), forKey: updateKey)
        let newLog: NSData = NSKeyedArchiver.archivedDataWithRootObject(dict)
        fileManager.createFileAtPath(lastUpdatePath, contents: newLog, attributes: nil)
        return true
    }
    println("getting log")
    let log = NSData(contentsOfFile: lastUpdatePath)
    println("getting key")
    if (log?.length <= 0){
        println("no key? update!")
        return true
    }
    let dict: NSDictionary = NSKeyedUnarchiver.unarchiveObjectWithData(log!)! as! NSDictionary
    let date = dict.valueForKey(updateKey) as! NSDate
    println("got key")
    let today = NSDate()
    if (daysBetween(date, today) > 7){
        println("should update")
        return true
    }
    else{
        println("No need to update")
        return false
    }
}

private func daysBetween(d1: NSDate, d2: NSDate) -> Int{
    let unitFlag = NSCalendarUnit.CalendarUnitDay
    let calendar: NSCalendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
    let components: NSDateComponents = calendar.components(unitFlag, fromDate: d1, toDate: d2, options: nil)
    return components.day;
}

