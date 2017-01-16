//
//  Handlers.swift
//  Swifter
//  Copyright (c) 2014 Damian Kołakowski. All rights reserved.
//

import Foundation
import AVFoundation

var audioPlayer: AVAudioPlayer = AVAudioPlayer()
var lastPlayedMp3: String = ""

open class HttpHandlers {

    open class func directory(_ dir: String) -> ( (HttpRequest) -> HttpResponse ) {
        return { request in
            if let localPath = request.capturedUrlGroups.first {
                let filesPath = dir.stringByExpandingTildeInPath.stringByAppendingPathComponent(localPath)
                if let fileBody = try? Data(contentsOf: URL(fileURLWithPath: filesPath)) {
                    return HttpResponse.raw(200, fileBody)
                }
            }
            return HttpResponse.notFound
        }
    }

    open class func directoryBrowser(_ dir: String) -> ( (HttpRequest) -> HttpResponse ) {
        return { request in
            if let pathFromUrl = request.capturedUrlGroups.first {
                let URLFromPath = URL(fileURLWithPath: pathFromUrl)
                let filePath = dir.stringByExpandingTildeInPath.stringByAppendingPathComponent(pathFromUrl)
                let fileManager = FileManager.default
                var isDir: ObjCBool = false;
                if ( fileManager.fileExists(atPath: filePath, isDirectory: &isDir) ) {
                    if ( isDir ).boolValue {
                        do {
                            let files = try fileManager.contentsOfDirectory(atPath: filePath)
                            var response = "<h3>\(filePath)</h3></br><table>"
                            response += files.map({ "<tr><td><a href=\"\(request.url)/\($0)\">\($0)</a></td></tr>"}).joined(separator: "")
                            response += "</table>"
                            return HttpResponse.ok(.html(response))
                        } catch  {
                            return HttpResponse.notFound
                        }
                    } else {
                        if let fileBody = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
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
                            
                            return HttpResponse.raw(200, fileBody)
                        }
                    }
                }
            }
            return HttpResponse.notFound
        }
    }
}

private extension String {
    var stringByExpandingTildeInPath: String {
        return (self as NSString).expandingTildeInPath
    }

    func stringByAppendingPathComponent(_ str: String) -> String {
        return (self as NSString).appendingPathComponent(str)
    }
}
