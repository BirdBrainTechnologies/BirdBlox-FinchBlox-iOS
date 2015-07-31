//
//  Handlers.swift
//  Swifter
//  Copyright (c) 2014 Damian Kołakowski. All rights reserved.
//

import Foundation
import AVFoundation

var audioPlayer: AVAudioPlayer = AVAudioPlayer()
var lastPlayedMp3: String = ""


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
                        if let files = fileManager.contentsOfDirectoryAtPath(filePath, error: nil) {
                            var response = "<h1>Index of /snap/\(pathFromUrl)</h1>\n<table>\n"
                            response += join("", map(files, { "<tr><td><a href=\"\($0)\">\($0)</a></td></tr>\n"}))
                            response += "</table>"
                            return HttpResponse.OK(.HTML(response))
                        }
                    } else {
                        if let fileBody = NSData(contentsOfFile: filePath) {
                            if(pathFromUrl.pathExtension == "wav" || pathFromUrl.pathExtension == "mp3"){
                                if pathFromUrl.pathExtension == "mp3"{
                                    if lastPlayedMp3 == ""{
                                        lastPlayedMp3 = pathFromUrl
                                    }
                                    else{
                                        if lastPlayedMp3 == pathFromUrl{
                                            lastPlayedMp3 = ""
                                            AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, error: nil)
                                            AVAudioSession.sharedInstance().setActive(true, error: nil)
                                            var error:NSErrorPointer = NSErrorPointer()
                                            audioPlayer = AVAudioPlayer(data: fileBody, fileTypeHint: pathFromUrl.pathExtension, error: error)
                                            audioPlayer.stop()
                                            audioPlayer.prepareToPlay()
                                            audioPlayer.play()

                                        } else{
                                            AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, error: nil)
                                            AVAudioSession.sharedInstance().setActive(true, error: nil)
                                            var error:NSErrorPointer = NSErrorPointer()
                                            audioPlayer = AVAudioPlayer(data: fileBody, fileTypeHint: pathFromUrl.pathExtension, error: error)
                                            audioPlayer.prepareToPlay()
                                            audioPlayer.play()
                                        }
                                    }
                                }
                                else{
                                    AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, error: nil)
                                    AVAudioSession.sharedInstance().setActive(true, error: nil)
                                    var error:NSErrorPointer = NSErrorPointer()
                                    audioPlayer = AVAudioPlayer(data: fileBody, fileTypeHint: pathFromUrl.pathExtension, error: error)
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