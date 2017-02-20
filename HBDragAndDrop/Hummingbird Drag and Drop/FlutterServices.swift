//
//  FlutterServices.swift
//  BirdBlox
//
//  Created by birdbrain on 2/20/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import CoreBluetooth

open class FlutterServices: NSObject{
    
    static let ServiceUUID = CBUUID(string: "BC2F4CC6-AAEF-4351-9034-D66268E328F0")
    static let TxUUID = CBUUID(string: "06D1E5E7-79AD-4A71-8FAA-373789F7D93C")//sending
    static let RxUUID = CBUUID(string: "818AE306-9C5B-448D-B51A-7ADD6A5D314D")//receiving
    
    fileprivate var trileds: [[UInt8]] = [[0,0,0],[0,0,0],[0,0,0]]
    fileprivate var trileds_time: [Double] = [0,0,0]
    fileprivate var servos: [UInt8] = [0,0,0]
    fileprivate var servos_time: [Double] = [0,0,0]
    fileprivate var lastKnowSensorPoll: [UInt8] = [0,0,0]
    fileprivate var name: String = ""
    
    
    var timerDelaySend: Timer?
    var allowSend = true
    let sendInterval = 0.06
    let readInterval = 0.2
    let cache_timeout: Double = 15.0 //in seconds
    let sharedBluetoothDiscovery = BluetoothDiscovery.getBLEDiscovery()
    let sendQueue = OperationQueue()
    
    public override init(){
        super.init()
        sendQueue.maxConcurrentOperationCount = 1
    }

}
