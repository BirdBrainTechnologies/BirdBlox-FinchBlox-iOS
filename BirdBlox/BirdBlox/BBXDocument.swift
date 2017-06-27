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
	var currentXML: String = ""
	
	override func load(fromContents contents: Any, ofType typeName: String?) throws {
		guard typeName == "bbx" else {
			throw NSError()
		}
		
		guard let contentData = (contents as? Data) else {
			throw NSError()
		}
		
		guard let xml = String(data: contentData, encoding: .utf8) else {
			throw NSError()
		}
		
		self.currentXML = xml
	}
	
	override func contents(forType typeName: String) throws -> Any {
		guard typeName == "bbx" else {
			throw NSError()
		}
		
		return (self.currentXML.data(using: .utf8) ?? Data()) as NSData
	}
}
