//
//  Handlers.swift
//  Swifter
//  Copyright (c) 2014 Damian Kołakowski. All rights reserved.
//

import Foundation
import AVFoundation

var audioPlayer: AVAudioPlayer = AVAudioPlayer()
var lastPlayedMp3: String = ""

public class HttpHandlers {

    public class func directory(dir: String) -> ( HttpRequest -> HttpResponse ) {
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

    public class func directoryBrowser(dir: String) -> ( HttpRequest -> HttpResponse ) {
        return { request in
            if let pathFromUrl = request.capturedUrlGroups.first {
                let URLFromPath = NSURL(fileURLWithPath: pathFromUrl)
                let filePath = dir.stringByExpandingTildeInPath.stringByAppendingPathComponent(pathFromUrl)
                let fileManager = NSFileManager.defaultManager()
                var isDir: ObjCBool = false;
                if ( fileManager.fileExistsAtPath(filePath, isDirectory: &isDir) ) {
                    if ( isDir ) {
                        do {
                            let files = try fileManager.contentsOfDirectoryAtPath(filePath)
                            var response = "<h3>\(filePath)</h3></br><table>"
                            response += files.map({ "<tr><td><a href=\"\(request.url)/\($0)\">\($0)</a></td></tr>"}).joinWithSeparator("")
                            response += "</table>"
                            return HttpResponse.OK(.HTML(response))
                        } catch  {
                            return HttpResponse.NotFound
                        }
                    } else {
                        if let fileBody = NSData(contentsOfFile: filePath) {
                            if(URLFromPath.pathExtension == "wav" || URLFromPath.pathExtension == "mp3" || URLFromPath.pathExtension == "m4a"){
                                do{
                                    try audioPlayer = AVAudioPlayer(data: fileBody, fileTypeHint: URLFromPath.pathExtension)
                                    try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
                                    try AVAudioSession.sharedInstance().setActive(true)
                                }
                                catch{
                                    print("Failed to setup audio player");
                                }
                                if URLFromPath.pathExtension == "mp3"{
                                    if lastPlayedMp3 == ""{
                                        lastPlayedMp3 = pathFromUrl
                                    }
                                    else{
                                        if lastPlayedMp3 == pathFromUrl{
                                            lastPlayedMp3 = ""
                                        }
                                            audioPlayer.prepareToPlay()
                                            audioPlayer.play()
                                    }
                                }
                                else{
                                    audioPlayer.prepareToPlay()
                                    audioPlayer.play()
                                }
                            }
                            
                            return HttpResponse.RAW(200, fileBody)
                        }
                    }
                }
            }
            return HttpResponse.NotFound
        }
    }
}

private extension String {
    var stringByExpandingTildeInPath: String {
        return (self as NSString).stringByExpandingTildeInPath
    }

    func stringByAppendingPathComponent(str: String) -> String {
        return (self as NSString).stringByAppendingPathComponent(str)
    }
}
