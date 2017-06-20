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
            try sharedAudioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
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
		//TODO: Use the data modle
		let location = DataModel.shared.recordingsLoc.appendingPathComponent(saveName + ".m4a")
		let settings = [
			AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
			AVSampleRateKey: 12000,
			AVNumberOfChannelsKey: 1,
			AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
		]
		
		//Try to get permission if we don't have it
		guard sharedAudioSession.recordPermission() == .granted else {
			sharedAudioSession.requestRecordPermission { permissionGranted in
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
	
	func finishRecording() {
		guard let recorder = self.recorder,
			recorder.isRecording else {
			return
		}
		
		recorder.stop()
		self.recorder = nil
	}
	
	func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
		self.finishRecording()
		//TODO: Do something with the flag
	}
	
	
	//MARK: Playing sounds
	
	public func getSoundNames () -> [String]{
		do {
			let paths = try FileManager.default.contentsOfDirectory(atPath:
				DataModel.shared.soundsLoc.path)
			let files = paths.filter {
				(DataModel.shared.soundsLoc.appendingPathComponent($0)).pathExtension == "wav"
			}
			return files
		} catch {
			return []
		}
	}
	
    func getSoundDuration(filename: String) -> Int {
        do {
            let player = try AVAudioPlayer(contentsOf:
				DataModel.shared.soundsLoc.appendingPathComponent(filename))
			
            //convert to milliseconds
            let audioDuration: Float64 = player.duration * 1000
            return Int(audioDuration)
        } catch {
            NSLog("Failed to get duration")
            return 0
        }
    }
    
    func playSound(filename: String) {
        do {
            let player = try AVAudioPlayer(contentsOf:
				DataModel.shared.soundsLoc.appendingPathComponent(filename))
            player.prepareToPlay()
            player.play()
            players.append(player)
        } catch {
            NSLog("failed to play: " + filename)
        }
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
		sampler.startNote(noteEightBit, withVelocity: 127, onChannel: 1)
		DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(duration)) {
			self.sampler.stopNote(noteEightBit, onChannel: 1)
		}
	
	}
	
    func stopTones() {
        audioEngine.stop()
        do {
            try audioEngine.start()
        } catch {
            NSLog("Failed to start audio player")
        }
    }
}
