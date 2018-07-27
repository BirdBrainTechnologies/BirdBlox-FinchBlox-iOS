//
//  CallbackManager.swift
//  BirdBlox
//
//  Created by Jeremy Huang on 2017-07-11.
//  Copyright © 2017年 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import WebKit

class BBXCallbackManager {
	static var current = BBXCallbackManager(webView: WKWebView())

	private let webView: WKWebView
	
	init(webView: WKWebView) {
		self.webView = webView
	}
	
	public enum Sensor {
		case Microphone, GPSReceiver, Barometer, Accelerometer
		
		func jsString() -> String {
			switch(self) {
			case .Microphone: return "microphone"
			case .GPSReceiver: return "gps"
			case .Barometer: return "barometer"
			case .Accelerometer: return "accelerometer"
			}
		}
	}
	
	public func addAvailableSensor(_ sensor: Sensor) {
		webView.evaluateJavaScript("CallbackManager.device.addSensor(\(sensor.jsString()))")
	}
	public func removeAvailableSensor(_ sensor: Sensor) {
		webView.evaluateJavaScript("CallbackManager.device.removeSensor(\(sensor.jsString()))")
	}
}
