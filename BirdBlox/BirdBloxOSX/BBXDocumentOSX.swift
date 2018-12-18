//
//  BBXDocumentOSX.swift
//  BirdBloxOSX
//
//  Created by Kristina Lauwers on 10/30/18.
//  Copyright © 2018 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import Zip

class BBXDocument: NSDocument {
    var realCurrentXML: String = "<project><tabs></tabs></project>"
    let xmlLoc = DataModel.shared.currentDocLoc
        .appendingPathComponent("program").appendingPathExtension("xml")
    let outLoc = DataModel.shared.stagingLoc
        .appendingPathComponent("outDoc").appendingPathExtension("zip")
    
    var recordingsDirectory: URL = DataModel.shared.recordingsLoc
    
    var currentXML: String {
        get {
            return self.realCurrentXML
        }
        
        set (newXML) {
            if self.realCurrentXML != newXML {
                self.realCurrentXML = newXML
                self.updateChangeCount(.changeDone)
            }
        }
    }
    
    
    
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        
        guard typeName == DataModel.bbxUTI else {
            throw NSError(domain: "Document Handling", code: -1, userInfo: nil)
        }
        
        guard let contentData = (contents as? Data) else {
            throw NSError(domain: "Document Handling", code: -2, userInfo: nil)
        }
        
        let zipPath = DataModel.shared.stagingLoc.appendingPathComponent("inDoc.zip")
        let unzipPath = DataModel.shared.currentDocLoc
        try contentData.write(to: zipPath)
        
        
        DataModel.shared.deleRecordingsDir()
        if ((try? Zip.unzipFile(zipPath, destination: unzipPath, overwrite: true, password: nil,
                                progress: nil)) != nil) {
            //The document is in the correct format
            //We will open program.xml
            //Make sure there is a recordings directory
        } else {
            //Let's hope it's the old format
            let _ = DataModel.shared.emptyCurrentDocument()
            try contentData.write(to: self.xmlLoc)
        }
        DataModel.shared.createDirectories()
        
        let xmlData = try Data(contentsOf: self.xmlLoc)
        
        guard let xml = String(data: xmlData, encoding: .utf8) else {
            throw NSError(domain: "Document Handling", code: -3, userInfo: nil)
        }
        
        self.currentXML = xml
    }
    
    override func contents(forType typeName: String) throws -> Any {
        print("Contents for type: \(typeName), name: \(self.localizedName)")
        
        guard typeName == DataModel.bbxUTI else {
            throw NSError(domain: "Document Handling", code: -1, userInfo: nil)
        }
        
        try self.currentXML.write(to: self.xmlLoc, atomically: true, encoding: .utf8)
        
        let filesToZip = try FileManager.default
            .contentsOfDirectory(at: DataModel.shared.currentDocLoc,
                                 includingPropertiesForKeys: nil)
        print("\(filesToZip)")
        
        print("about to zip")
        try Zip.zipFiles(paths: filesToZip, zipFilePath: self.outLoc, password: nil,
                         compression: .NoCompression, progress: nil)
        print("finish zip")
        
        guard let retData = NSData(contentsOf: self.outLoc) else {
            throw NSError(domain: "Document Handling", code: -1, userInfo: nil)
        }
        return retData
    }
    
    override func handleError(_ error: Error, userInteractionPermitted: Bool) {
        NSLog("Error in BBXDocument: \(error), UI permitted: \(userInteractionPermitted)")
    }
}
