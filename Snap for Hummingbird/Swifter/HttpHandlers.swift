//
//  Handlers.swift
//  Swifter
//  Copyright (c) 2014 Damian Kołakowski. All rights reserved.
//

import Foundation

class HttpHandlers {

    class func directory(dir: String) -> ( HttpRequest -> HttpResponse ) {
        return { request in
            if let localPath = request.capturedUrlGroups.first {
                let filesPath = dir.stringByExpandingTildeInPath.stringByAppendingPathComponent(localPath)
                if let fileBody = NSData(contentsOfFile: filesPath) {
                    return HttpResponse.RAW(200, fileBody)
                }
            }
            return HttpResponse.NotFound
        }
    }

    class func directoryBrowser(dir: String) -> ( HttpRequest -> HttpResponse ) {
        return { request in
            if let pathFromUrl = request.capturedUrlGroups.first {
                let filePath = dir.stringByExpandingTildeInPath.stringByAppendingPathComponent(pathFromUrl)
                let fileManager = NSFileManager.defaultManager()
                var isDir: ObjCBool = false;
                if ( fileManager.fileExistsAtPath(filePath, isDirectory: &isDir) ) {
                    if ( isDir ) {
                        if(pathFromUrl == "Sounds"){
                            let path = NSBundle.mainBundle().pathForResource("Sounds", ofType: "html")
                            let rawText = String(contentsOfFile: path!, encoding: NSUTF8StringEncoding, error: nil)
                            return HttpResponse.OK(.RAW(rawText!))
                        }
                        if(pathFromUrl == "Examples" || pathFromUrl == "Examples/"){
                            let path = NSBundle.mainBundle().pathForResource("Examples", ofType: "html")
                            let rawText = String(contentsOfFile: path!, encoding: NSUTF8StringEncoding, error: nil)
                            return HttpResponse.OK(.RAW(rawText!))
                        }
                        if(pathFromUrl == "Costumes"){
                            let path = NSBundle.mainBundle().pathForResource("Costumes", ofType: "html")
                            let rawText = String(contentsOfFile: path!, encoding: NSUTF8StringEncoding, error: nil)
                            return HttpResponse.OK(.RAW(rawText!))
                        }
                        if let files = fileManager.contentsOfDirectoryAtPath(filePath, error: nil) {
                            var response = "<h3>\(filePath)</h3></br><table>"
                            response += join("", map(files, { "<tr><td><a href=\"\(request.url)/\($0)\">\($0)</a></td></tr>"}))
                            response += "</table>"
                            return HttpResponse.OK(.HTML(response))
                        }
                    } else {
                        if let fileBody = NSData(contentsOfFile: filePath) {
                            return HttpResponse.RAW(200, fileBody)
                        }
                    }
                }
            }
            return HttpResponse.NotFound
        }
    }
}