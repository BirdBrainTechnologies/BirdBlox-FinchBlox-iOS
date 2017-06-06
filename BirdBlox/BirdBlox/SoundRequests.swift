//
//  DataRequests.swift
//  BirdBlox
//
//  Created by birdbrain on 4/27/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import Swifter

class SoundManager: NSObject {

    let audio_manager: AudioManager
    
    override init(){
        audio_manager = AudioManager()
        super.init()
    }
    
    func loadRequests(server: BBTBackendServer){
        server["/sound/names"] = namesRequest(request:)
        server["/sound/stopAll"] = stopAllRequest(request:)
        server["/sound/stop"] = stopRequest(request:)

        
        server["/sound/duration"] = durationRequest(request:)
        server["/sound/play"] = playRequest(request:)
        server["/sound/note"] = noteRequest(request:)
    }
    
    func namesRequest(request: HttpRequest) -> HttpResponse {
        let soundList = audio_manager.getSoundNames()
        var sounds: String = "";
        soundList.forEach({ (string) in
            sounds.append(string)
            sounds.append("\n")
        })
        return .ok(.text(sounds))
    }
    
    func stopAllRequest(request: HttpRequest) -> HttpResponse {
        self.audio_manager.stopTones()
        self.audio_manager.stopSounds()
        return .ok(.text("Sounds All Audio"))
    }
    
    func stopRequest(request: HttpRequest) -> HttpResponse {
        self.audio_manager.stopSounds()
        return .ok(.text("Sounds Stopped"))
    }
    
    func durationRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		guard let filename = queries["filename"] else {
			return .badRequest(.text("Missing query parameter"))
		}
        return .ok(.text(String(self.audio_manager.getSoundDuration(filename: filename))))
    }
    
    func playRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		guard let filename = queries["filename"] else {
			return .badRequest(.text("Missing query parameter"))
		}
        self.audio_manager.playSound(filename: filename)
        return .ok(.text("Playing sound"))
    }
    
    func noteRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		guard let noteStr = queries["note"],
			let durStr = queries["duration"],
			let note = UInt(noteStr),
			let duration = Int(durStr) else {
			return .badRequest(.text("Missing query parameter"))
		}
        self.audio_manager.playNote(noteIndex: note, duration: duration)
        return .ok(.text("Playing Note"))
    }
    
}
