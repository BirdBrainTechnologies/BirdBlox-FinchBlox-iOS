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
    var player: AVAudioPlayer
    
    override init() {
        //super.init()
        // Instatiate audio engine
        audioEngine = AVAudioEngine()
    
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
        player = AVAudioPlayer()
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
        try player = AVAudioPlayer(contentsOf: getSoundPath().appendingPathComponent(filename))
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
            try player = AVAudioPlayer(contentsOf: getSoundPath().appendingPathComponent(filename))
            player.prepareToPlay()
            player.play()
        } catch {
            NSLog("failed to play: " + filename)
        }
    }
    
}
