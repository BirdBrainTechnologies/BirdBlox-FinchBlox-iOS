//
//  DocumentManager.swift
//  BirdBlox
//
//  Created by birdbrain on 3/21/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import Zip


class DataModel: NSObject {
	static let bbxUTI = "com.birdbraintechnologies.bbx"
	static let shared = DataModel()
	
	let documentLoc: URL
	let bundleLoc: URL
	
	let bbxSaveLoc: URL
	
	let tmpLoc: URL
	let stagingLoc: URL
	let currentDocLoc: URL
	let recordingsLoc: URL
	
	let frontendLoc: URL
	let frontendPageLoc: URL
	let soundsLoc: URL
	let uiSoundsLoc: URL
	
	override init() {
		do {
			let docLoc = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
			                                         appropriateFor: nil, create: true)
			self.documentLoc = docLoc
		} catch {
			NSLog("FileManager.default.url failed")
			let docPath = NSSearchPathForDirectoriesInDomains(.documentDirectory,
			                                                  .userDomainMask, true)[0]
			self.documentLoc = URL(fileURLWithPath: docPath)
		}
		
		do {
			let docLoc = self.documentLoc
			let tmpLoc = try FileManager.default.url(for: .itemReplacementDirectory,
			                                         in: .userDomainMask, appropriateFor: docLoc,
			                                         create: true)
			self.tmpLoc = tmpLoc
		} catch {
			let tmpPath = NSSearchPathForDirectoriesInDomains(.itemReplacementDirectory,
			                                                  .userDomainMask, true)[0]
			self.tmpLoc = URL(fileURLWithPath: tmpPath)
		}
		
		self.stagingLoc = self.tmpLoc.appendingPathComponent("staging")
		self.currentDocLoc = self.tmpLoc.appendingPathComponent("currentDoc")
		self.recordingsLoc = self.currentDocLoc.appendingPathComponent("recordings")
		
		self.bundleLoc = URL(string: Bundle.main.bundleURL.path)!
		
		self.bbxSaveLoc = self.documentLoc
		
		#if DEBUG
			if let unzipLoc = DataModel.updateAndGetDevFrontendURL() {
				self.frontendLoc = unzipLoc
			}
			else {
				self.frontendLoc = bundleLoc.appendingPathComponent("Frontend")
			}
		#else
			NSLog("Running in a non-DEBUG mode, going to use local frontend.")
			self.frontendLoc = bundleLoc.appendingPathComponent("Frontend")
		#endif
		
		self.frontendPageLoc = self.frontendLoc.appendingPathComponent("HummingbirdDragAndDrop.html")
		self.soundsLoc = self.frontendLoc.appendingPathComponent("SoundClips")
		self.uiSoundsLoc = self.frontendLoc.appendingPathComponent("SoundsForUI")
		
		
		super.init()
		
		//Check the folders exists
		
		if !FileManager.default.fileExists(atPath: self.recordingsLoc.path) {
			do {
				try FileManager.default.createDirectory(atPath: self.recordingsLoc.path,
														withIntermediateDirectories: true,
														attributes: nil)
			}
			catch {
				NSLog("Unable to create recordings directory")
			}
		}
		
		if !FileManager.default.fileExists(atPath: self.stagingLoc.path) {
			do {
				try FileManager.default.createDirectory(atPath: self.stagingLoc.path,
				                                        withIntermediateDirectories: true,
				                                        attributes: nil)
			}
			catch {
				NSLog("Unable to create stagingLoc directory")
			}
		}
		
		//Change old file structure
		//TODO: Remove this code once it has been wild for long enoguh to fix the vast majority of 
		//documents directories. Since the user could be in charge of it and add files or 
		//directories to it, we don't want to be silently messing with folders that they want to be
		//in the documents directory. – Jeremy
		let settingsPlistLoc = self.documentLoc.appendingPathComponent("Settings.plist")
		if FileManager.default.fileExists(atPath: settingsPlistLoc.path) {
			do {
				try FileManager.default.removeItem(at: settingsPlistLoc)
			} catch {
				NSLog("Unable to remove old settings plist.")
			}
		}
		
		let oldBBXSaveLoc = self.documentLoc.appendingPathComponent("SavedFiles")
		
		if let files = try? FileManager.default.contentsOfDirectory(at: oldBBXSaveLoc,
		                                                            includingPropertiesForKeys: nil,
																	options: .skipsHiddenFiles) {
			for fileURL in files {
				do {
					try FileManager.default.moveItem(at: fileURL, to: self.bbxSaveLoc)
				} catch {
					NSLog("Unable to move file from old save location from \(fileURL.path)")
				}
			}
		}
		
		let oldRecordignsLoc = self.documentLoc.appendingPathComponent("Recordings")
		if FileManager.default.fileExists(atPath: oldRecordignsLoc.path) {
			do {
				try FileManager.default.removeItem(at: oldRecordignsLoc)
			} catch {
				NSLog("Unable to remove old recording plist.")
			}
		}
	}
	
	
	//MARK: Managing User Facing Files
	
	public enum BBXFileType: String {
		case SoundRecording
		case BirdBloxProgram
		case SoundEffect
		case SoundUI
		
		var fileExtension: String {
			switch self {
			
			case .SoundRecording:
				return "m4a"
			
			case .BirdBloxProgram:
				return "bbx"
			
			case .SoundEffect,
			     .SoundUI:
				return "wav"
			}
		}
	}
	
	func folder(of fileType: BBXFileType) -> URL {
		switch fileType {
		case .SoundRecording:
			return self.recordingsLoc
		case .BirdBloxProgram:
			return self.bbxSaveLoc
		case .SoundEffect:
			return self.soundsLoc
		case .SoundUI:
			return self.uiSoundsLoc
		}
	}
	
	func fileLocation(forName name: String, type: BBXFileType) -> URL {
		let url = self.folder(of: type).appendingPathComponent(name).appendingPathExtension(type.fileExtension)
		
		return url
	}
	
	private func namesOfsavedFiles(ofType type: BBXFileType) -> [String] {
		let path = self.folder(of: type).path
		do {
			let paths = try FileManager.default.contentsOfDirectory(
				atPath: path)
			return paths
		} catch {
			return []
		}
	}
	
	private func filenameAvailalbe(name: String, type: BBXFileType) -> Bool {
		guard DataModel.nameIsSanitary(name) else {
			return false
		}
		
		return !FileManager.default.fileExists(
			atPath: self.getBBXFileLoc(byName: name).path)
	}
	
	private func deleteFile(byName name: String, type: BBXFileType) -> Bool {
		let path = self.fileLocation(forName: name, type: type).path
		do {
			try FileManager.default.removeItem(atPath: path)
			return true
		} catch {
			return false
		}
	}
	
	private func renameFile(from: String, to: String, type: BBXFileType) -> Bool {
		let curPath = self.fileLocation(forName: from, type: type).path
		let newPath = self.fileLocation(forName: to, type: type).path
		
		do {
			try FileManager.default.moveItem(atPath: curPath, toPath: newPath)
			return true
		} catch {
			return false
		}
	}
	
	
	//MARK: Managing file names
	
	// Replaces disallowed characters with underscores
	public static func sanitizedName(of name: String) -> String {
		guard name.characters.count > 0 else {
			return "_"
		}
		
		let blackList = ["\\", "/", ":", "*", "?", "<", ">", "|", ".", "\n", "\r", "\0", "\"", "$"]
		let replacement = "_"
		
		var sanitizedString = name
		for bannedChar in blackList {
			sanitizedString = sanitizedString.replacingOccurrences(of: bannedChar,
			                                                       with: replacement)
		}
		
		return sanitizedString
	}
	
	public static func nameIsSanitary(_ name: String) -> Bool {
		return name == DataModel.sanitizedName(of: name)
	}
	
	private func getNumberSuffix(from name: String) -> UInt? {
		let chars = name.characters
		guard chars.last == Character(")") else {
			return nil
		}
		
		var curIndex = chars.index(before: chars.endIndex)
		while chars[curIndex] != Character("(") {
			curIndex = chars.index(before: curIndex)
		}
		let intPart = name.substring(with:
			chars.index(after: curIndex)..<chars.index(before: chars.endIndex))
		
		return UInt(intPart)
	}
	
	private func getRootOf(name: String) -> String {
		let chars = name.characters
		var curIndex = chars.index(before: chars.endIndex)
		while chars[curIndex] != Character("(") {
			curIndex = chars.index(before: curIndex)
		}
		return name.substring(to: curIndex)
	}
	
	public func availableName(from name: String) -> String? {
		return self.availableNameRecHelper(from: DataModel.sanitizedName(of: name))
	}
	
	func availableNameRecHelper(from name: String) -> String {
		if self.bbxNameAvailable(name) {
			return name
		}
		
		let suffixNumO = self.getNumberSuffix(from: name)
		var suffixNum: UInt = 2
		var prefixName = name
		if let suffixNumO = suffixNumO {
			suffixNum = suffixNumO + 1
			prefixName = self.getRootOf(name: name)
		}
		
		return availableNameRecHelper(from: "\(prefixName)(\(suffixNum))")
	}
	
	//MARK: Managing BBX Programs
	
	public var savedBBXFiles: [String] {
		return self.namesOfsavedFiles(ofType: .BirdBloxProgram)
	}
	
	func getBBXFileLoc(byName filename: String) -> URL {
		return self.fileLocation(forName: filename, type: .BirdBloxProgram)
	}
	
	public func bbxNameAvailable(_ name: String) -> Bool {
		return self.filenameAvailalbe(name: name, type: .BirdBloxProgram)
	}
	
	public func getBBXContent(byName filename: String) -> String? {
		let path = self.getBBXFileLoc(byName: filename).path
		
		guard FileManager.default.fileExists(atPath: path) else {
			return nil
		}
		
		do {
			let file = try String(contentsOfFile: path, encoding: String.Encoding.utf8)
			return file
		} catch {
			return nil
		}
	}
	
	public func save(bbxString: String, withName filename: String) -> Bool{
		let isDir: UnsafeMutablePointer<ObjCBool>? = nil
		
		//Make sure the save directory exists
		if !FileManager.default.fileExists(atPath: self.bbxSaveLoc.path,
		                                   isDirectory: isDir) {
			do {
				try FileManager.default.createDirectory(atPath: self.bbxSaveLoc.path,
				                                        withIntermediateDirectories: false,
														attributes: nil)
			}
			catch {
				return false
			}
		}
		
		//Write the string to disk
		let path = self.getBBXFileLoc(byName: filename).path
		do {
			try bbxString.write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
			return true
		}
		catch {
			return false
		}
	}
	
	public func deleteBBXFile(byName filename: String) -> Bool {
		return self.deleteFile(byName: filename, type: .BirdBloxProgram)
	}
	
	public func renameBBXFile(from curName: String, to newName: String) -> Bool {
		return self.renameFile(from: curName, to: newName, type: .BirdBloxProgram)
	}
	
	
	//MARK: Managing Settings
	
	public func addSetting(_ key: String, value: String) {
		UserDefaults.standard.set(value, forKey: key)
	}
	
	public func getSetting(_ key: String) -> String? {
		return UserDefaults.standard.string(forKey: key)
	}
	
	
	#if DEBUG
	//MARK: Downloading new frontend for debug
	
	static private func BBTDownloadFrontendUpdate(from repoUrl: URL, to zipPath: URL) -> Bool{
		do {
			let zippedData = try NSData(contentsOf: repoUrl,
	                                    options: [NSData.ReadingOptions.uncached])
			zippedData.write(toFile: zipPath.path, atomically: true)
			
			return true;
		}
		catch {
			return false;
		}
	}
	
	static private func BTTOverwriteFrontendWithDownload(from zipPath: URL,
	                                                     to unzipPath: URL) -> Bool {
		do {
			try Zip.unzipFile(zipPath,
			                  destination: unzipPath,
			                  overwrite: true,
			                  password: nil,
		                   progress: { (progress) -> () in })
			
			return true
		}
		catch {
			return false
		}
	}
	
	static private func updateAndGetDevFrontendURL() -> URL? {
		//TomWildenhain, BirdBrainTechnologies
		//From Tom: https://github.com/TomWildenhain/HummingbirdDragAndDrop-/archive/dev.zip
		//Semi Stable: https://github.com/BirdBrainTechnologies/HummingbirdDragAndDrop-/archive/dev.zip
		let repoUrl = URL(string:"https://github.com/BirdBrainTechnologies/HummingbirdDragAndDrop-/archive/dev.zip")!
		let documentLoc = URL(string:
			NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory,
			FileManager.SearchPathDomainMask.userDomainMask,
			true)[0])!
		let zipPath = documentLoc.appendingPathComponent("temp.zip")
		let unzipPath = documentLoc.appendingPathComponent("DragAndDrop")
		
		NSLog("Running in DEBUG mode. Going to overwrite current frontend from git.")
		guard BBTDownloadFrontendUpdate(from: repoUrl, to: zipPath) else {
			NSLog("Unable to download zip from repo. Going to use bundled frontend.")
			return nil
		}
		guard BTTOverwriteFrontendWithDownload(from: zipPath, to: unzipPath) else {
			NSLog("Unable to unzip frontend. Frontend might be broken.")
			return nil
		}
		
		NSLog("Successfully downloaded new frontend.")
	
		do {
			let subDirs = try FileManager.default.contentsOfDirectory(atPath: unzipPath.path)
			
			guard subDirs.count == 1 else {
				return nil
			}
	
			//The frontend folder should be the only folder in the unzip folder
			return URL(string:unzipPath.appendingPathComponent(subDirs[0]).path)
		} catch {
			return nil
		}
	}
	
	#endif
}

