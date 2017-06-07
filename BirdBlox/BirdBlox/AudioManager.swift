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


class AudioManager: NSObject {
    var audioEngine:AVAudioEngine
    var sampler:AVAudioUnitSampler
    var mixer:AVAudioMixerNode
    var players:[AVAudioPlayer]
    
    override init() {
        //super.init()
        // Instatiate audio engine
        audioEngine = AVAudioEngine()
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            }
            catch {
                NSLog("Failed to set audio session")
            }
        }
        catch {
            NSLog("Failed to set audio session")
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
    
    func getSoundDuration(filename: String) -> Int {
        do {
            let player = try AVAudioPlayer(contentsOf: DataModel.shared.soundsLoc.appendingPathComponent(filename))
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
            let player = try AVAudioPlayer(contentsOf: DataModel.shared.soundsLoc.appendingPathComponent(filename))
            player.prepareToPlay()
            player.play()
            players.append(player)
        } catch {
            NSLog("failed to play: " + filename)
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
    
    func stopSounds() {
        for player in players {
            player.stop()
        }
        players.removeAll()
    }
    
    public func getSoundNames () -> [String]{
        do {
            let paths = try FileManager.default.contentsOfDirectory(atPath: DataModel.shared.soundsLoc.path)
            let files = paths.filter{ (DataModel.shared.soundsLoc.appendingPathComponent($0)).pathExtension == "wav" }
            return files
        } catch {
            return []
        }
    }
    
}
