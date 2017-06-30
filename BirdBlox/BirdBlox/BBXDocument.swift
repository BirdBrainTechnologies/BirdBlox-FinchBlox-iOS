//
//  BBXDocument.swift
//  BirdBlox
//
//  Created by Jeremy Huang on 2017-06-27.
//  Copyright © 2017年 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import UIKit

//TODO: Switch from XML file to container with xml and sound recordings

class BBXDocument: UIDocument {
	var realCurrentXML: String = ""
	
	var currentXML: String {
		get {
			return self.realCurrentXML
		}
		
		set (newXML) {
			if self.realCurrentXML != newXML {
				print("Change occurred to document")
				self.realCurrentXML = newXML
				self.updateChangeCount(.done)
			}
		}
	}
	
	override func load(fromContents contents: Any, ofType typeName: String?) throws {
		print("load from contents. Type \(typeName ?? "None")")
		guard typeName == "dyn.ah62d4rv4ge80e2x2" else {
			throw NSError(domain: "Document Handling", code: -1, userInfo: nil)
		}
		
		guard let contentData = (contents as? Data) else {
			throw NSError(domain: "Document Handling", code: -2, userInfo: nil)
		}
		
		guard let xml = String(data: contentData, encoding: .utf8) else {
			throw NSError(domain: "Document Handling", code: -3, userInfo: nil)
		}
		
		self.currentXML = xml
	}
	
	override func contents(forType typeName: String) throws -> Any {
		print("Contents for type: \(typeName)")
		
		guard typeName == "dyn.ah62d4rv4ge80e2x2" else {
			throw NSError(domain: "Document Handling", code: -1, userInfo: nil)
		}
		
		return (self.currentXML.data(using: .utf8) ?? Data()) as NSData
	}
	
	override func handleError(_ error: Error, userInteractionPermitted: Bool) {
		print("Error in BBXDocument: \(error), UI permitted: \(userInteractionPermitted)")
	}
}
