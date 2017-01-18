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
        do {
            try audioEngine.start()
        } catch {
            NSLog("Failed to start audio player")
        }
    }
    func playNote(noteIndex: UInt8, duration: Int) {
        sampler.startNote(noteIndex, withVelocity: 127, onChannel: 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(duration)) {
            self.sampler.stopNote(noteIndex, onChannel: 1)
        }
        
    }
}
