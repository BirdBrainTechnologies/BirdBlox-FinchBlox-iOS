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
	
	
	//MARK: Request Handlers
	
    func namesRequest(request: HttpRequest) -> HttpResponse {
        let soundList = audio_manager.getSoundNames()
        return .ok(.text(soundList.joined(separator: "\n")))
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
		
		guard let filename = queries["filename"],
			let typeStr = queries["type"],
			let type = self.soundFileType(fromParameter: typeStr) else {
			return .badRequest(.text("Missing or invalid query parameter"))
		}
		
		guard self.audio_manager.playSound(filename: filename, type: type) else {
			return .internalServerError
		}
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
	
	
	//MARK: Supporting functions
	private func soundFileType(fromParameter: String) -> DataModel.BBXFileType? {
		switch fromParameter {
		case "ui":
			return DataModel.BBXFileType.SoundUI
		case "recording":
			return DataModel.BBXFileType.SoundRecording
		case "effect":
			return DataModel.BBXFileType.SoundEffect
		default:
			return nil
		}
	}
}
