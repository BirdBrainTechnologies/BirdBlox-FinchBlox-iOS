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
		
		server["/sound/recording/start"] = startRecording(request:)
		server["/sound/recording/stop"] = stopRecording(request:)
		server["/sound/recording/pause"] = self.pauseRecording
		server["/sound/recording/unpause"] = self.unpauseRecording
		server["/sound/recording/discard"] = self.discardRecording
    }
	
	
	//MARK: Request Handlers
	
	func startRecording(request: HttpRequest) -> HttpResponse {
		let now = Date(timeIntervalSinceNow: 0)
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy-MM-dd HH`mm`ss ZZ"
		formatter.timeZone = TimeZone.current
		let name = DataModel.sanitizedName(of: formatter.string(from: now))
		let _ = self.audio_manager.startRecording(saveName: name)
		
		if self.audio_manager.permissionsState == .granted {
			return .ok(.text("Started"))
		} else if self.audio_manager.permissionsState == .undetermined {
			return .ok(.text("Requesting permission"))
		} else {
			return .ok(.text("Permission denied"))
		}
	}
	
	func stopRecording(request: HttpRequest) -> HttpResponse {
		self.audio_manager.finishRecording()
		
		return .ok(.text("finished recording"))
	}
	
	func discardRecording(request: HttpRequest) -> HttpResponse {
		self.audio_manager.finishRecording(deleteRecording: true)
		
		return .ok(.text("Discarded recording"))
	}
	
	func pauseRecording(request: HttpRequest) -> HttpResponse {
		let suc = self.audio_manager.pauseRecording()
		
		if suc {
			return .ok(.text("paused"))
		} else {
			return .raw(428, "Not recording", nil, nil)
		}
	}
	
	func unpauseRecording(request: HttpRequest) -> HttpResponse {
		let suc = self.audio_manager.unpauseRecording()
		
		if suc {
			return .ok(.text("paused"))
		} else {
			return .raw(428, "Not recording", nil, nil)
		}
	}
	
    func namesRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		guard let typeStr = queries["type"],
			let type = self.soundFileType(fromParameter: typeStr) else {
				return .badRequest(.text("Missing or invalid query parameter"))
		}
		
		let fsoundList = self.audio_manager.getSoundNames(type: type)
		
		let soundList = fsoundList.map {
			$0.replacingOccurrences(of: "." + type.fileExtension, with: "")
		}
		
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
		
		guard let filename = queries["filename"],
			let typeStr = queries["type"],
			let type = self.soundFileType(fromParameter: typeStr) else {
				return .badRequest(.text("Missing or invalid query parameter"))
		}
		
        return .ok(.text(String(self.audio_manager.getSoundDuration(filename: filename,
                                                                    type: type))))
    }
    
    func playRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		guard let filename = queries["filename"],
			let typeStr = queries["type"],
			let type = self.soundFileType(fromParameter: typeStr) else {
			return .badRequest(.text("Missing or invalid query parameter"))
		}
		
		let suc = self.audio_manager.playSound(filename: filename, type: type)
		
		guard suc else {
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
