//
//  AudioManager.swift
//  BirdBlox
//
//  Created by birdbrain on 1/18/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import AudioToolbox
import AVFoundation


class AudioManager: NSObject, AVAudioRecorderDelegate {
    var audioEngine:AVAudioEngine
    var sampler:AVAudioUnitSampler
    var mixer:AVAudioMixerNode
    var players:[AVAudioPlayer]
	let sharedAudioSession: AVAudioSession = AVAudioSession.sharedInstance()
	var recorder: AVAudioRecorder?
    
    override init() {
        //super.init()
        // Instatiate audio engine
        self.audioEngine = AVAudioEngine()
		
        do {
            //try sharedAudioSession.setCategory(convertFromAVAudioSessionCategory(AVAudioSession.Category.playAndRecord))
            if #available(iOS 11.0, *) {
                //try sharedAudioSession.setCategory(.playAndRecord, mode: .default)
                try sharedAudioSession.setCategory(.playback, mode: .default)
            } else {
                try AVAudioSessionPatch.setAudioSession()
            }
            
            do {
                try sharedAudioSession.setActive(true)
            }
            catch {
                NSLog("Failed to set audio session as active")
            }
        }
        catch {
            NSLog("Failed to set audio session category")
        }
        // get the reference to the mixer to
        // connect the output of the AVAudio
        mixer = audioEngine.mainMixerNode
        
        // instantiate sampler. Initialization arguments
        // are currently unneccesary
        sampler = AVAudioUnitSampler()
        
        // add sampler to audio engine graph
        // and connect it to the mixer node
        audioEngine.attach(sampler)
        audioEngine.connect(sampler, to: mixer, format: nil)
        players = [AVAudioPlayer]()
        do {
            try audioEngine.start()
        } catch {
            NSLog("Failed to start audio player")
        }
    }
	
	
	
	//MARK: Recording Audio
	
	public func startRecording(saveName: String) -> Bool {
        
        if #available(iOS 11.0, *) {
            do {
                try sharedAudioSession.setCategory(.record, mode: .default)
            } catch {
                NSLog("Failed to set record mode in startRecording.")
            }
        }
        
        
		//TODO: Use the data model
		let location = DataModel.shared.recordingsLoc.appendingPathComponent(saveName + ".m4a")
		let settings = [
			AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
			AVSampleRateKey: 12000,
			AVNumberOfChannelsKey: 1,
			AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
		]
		
		//Try to get permission if we don't have it
		guard sharedAudioSession.recordPermission == .granted else {
			sharedAudioSession.requestRecordPermission { permissionGranted in
				if permissionGranted {
//					BBXCallbackManager.current.addAvailableSensor(.Microphone)
				} else {
//					BBXCallbackManager.current.removeAvailableSensor(.Microphone)
				}
				return
			}
			
			//The frontend can put up a dialog to tell the user how to give us permission
			return false
		}
		
		do {
			self.recorder = try AVAudioRecorder(url: location, settings: settings)
			self.recorder?.delegate = self
			self.recorder?.record()
		} catch {
			self.finishRecording()
			return false
		}
		
		return true
	}
	
	public func pauseRecording() -> Bool {
		guard let recorder = self.recorder else {
			return false
		}
		
		recorder.pause()
        
        if #available(iOS 11.0, *) {
            do {
                try sharedAudioSession.setCategory(.playback, mode: .default)
            } catch {
                NSLog("Failed to set playback mode in pauseRecording.")
            }
        }
		
		return true
	}
	
	public func unpauseRecording() -> Bool {
		guard let recorder = self.recorder else {
			return false
		}
        
        if #available(iOS 11.0, *) {
            do {
                try sharedAudioSession.setCategory(.record, mode: .default)
            } catch {
                NSLog("Failed to set record mode in unpauseRecording.")
            }
        }
		
		return recorder.record()
	}
	
    @objc
	public func finishRecording(deleteRecording: Bool = false) {
		guard let recorder = self.recorder,
			recorder.currentTime != 0 else {
			return
		}
		
		recorder.stop()
		
		if deleteRecording {
			recorder.deleteRecording()
			try? FileManager.default.removeItem(at: recorder.url)
		}
		
		self.recorder = nil
        
        if #available(iOS 11.0, *) {
            do {
                try sharedAudioSession.setCategory(.playback, mode: .default)
            } catch {
                NSLog("Failed to set playback mode in finishRecording.")
            }
        }
		
		let _ = FrontendCallbackCenter.shared.recordingEnded()
	}
	
	func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
		self.finishRecording(deleteRecording: !flag)
	}
	
	var permissionsState: AVAudioSession.RecordPermission {
		return sharedAudioSession.recordPermission
	}
	
	
	//MARK: Playing sounds
	
	public func getSoundNames(type: DataModel.BBXFileType) -> [String]{
		do {
			let paths = try FileManager.default.contentsOfDirectory(atPath:
				DataModel.shared.folder(of: type).path)
//			let files = paths.filter {
//				(DataModel.shared.soundsLoc.appendingPathComponent($0)).pathExtension == "wav"
//			}
			print(type)
			print(paths)
			let files = paths
			return files
		} catch {
			NSLog("Listing sounds failed.")
			return []
		}
	}
	
	func getSoundDuration(filename: String, type: DataModel.BBXFileType) -> Int {
        do {
            let player = try AVAudioPlayer(contentsOf:
				DataModel.shared.fileLocation(forName: filename, type: type))
			
            //convert to milliseconds
			print("\(player.duration) secs")
            let audioDuration: Float64 = player.duration * 1000
            return Int(audioDuration)
        } catch {
            NSLog("Failed to get duration")
            return 0
        }
    }
    
	func playSound(filename: String, type: DataModel.BBXFileType) -> Bool {
		print("play sound")
        do {
			let loc = DataModel.shared.fileLocation(forName: filename, type: type)
			print("\(FileManager.default.fileExists(atPath: loc.path))")
            let player = try AVAudioPlayer(contentsOf: loc)
			
            player.prepareToPlay()
            player.play()
            players.append(player)
        } catch {
            NSLog("failed to play: " + filename)
			return false
        }
		return true
    }
	
	func stopSounds() {
		for player in players {
			player.stop()
		}
		players.removeAll()
	}


	//MARK: Playing Tones/Notes
	
	func playNote(noteIndex: UInt, duration: Int) {
		var cappedNote = noteIndex
		if(cappedNote >= UInt(UInt8.max)) {
			cappedNote = 255
		}
		let noteEightBit = UInt8(cappedNote)
        
        if !audioEngine.isRunning {
            NSLog("Restarting audio engine...")
            do {
                try audioEngine.start()
            } catch {
                NSLog("Failed to start engine")
                return
            }
        }
        
        print("Playing note \(noteEightBit)")
		sampler.startNote(noteEightBit, withVelocity: 127, onChannel: 1)
		DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(duration)) {
			self.sampler.stopNote(noteEightBit, onChannel: 1)
		}
	
	}
	
    /*
     * Stop any notes that are playing. 120 is the midi controller value for stop all
     * see https://www.midi.org/specifications-old/item/table-1-summary-of-midi-message
     */
    func stopTones() {
        sampler.sendController(120, withValue: 0, onChannel: 1)
        /*
        audioEngine.stop()
        do {
            try audioEngine.start()
        } catch {
            NSLog("Failed to start audio player")
        }*/
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
	return input.rawValue
}
