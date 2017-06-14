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
	static let shared = DataModel()
	
	let documentLoc: URL
	let bundleLoc: URL
	
	let bbxSaveLoc: URL
	let recordingsLoc: URL
	let settingsPlistLoc: URL
	
	let frontendLoc: URL
	let frontendPageLoc: URL
	let soundsLoc: URL
	
	override init() {
		self.documentLoc = URL(string:
			NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory,
			                                    FileManager.SearchPathDomainMask.userDomainMask,
			                                    true)[0])!
		self.bundleLoc = URL(string: Bundle.main.bundleURL.path)!
		
		self.bbxSaveLoc = self.documentLoc.appendingPathComponent("SavedFiles")
		self.recordingsLoc = self.documentLoc.appendingPathComponent("Recordings")
		self.settingsPlistLoc = self.documentLoc.appendingPathComponent("Settings.plist")
		
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
		
		
		super.init()
	}
	
	
	//MARK: Managing User Facing Files
	
	public enum BBXFileType {
		case SoundRecording
		case BirdBloxProgram
	}
	
	private func folder(of fileType: BBXFileType) -> URL {
		switch fileType {
		case .SoundRecording:
			return self.recordingsLoc
		case .BirdBloxProgram:
			return self.bbxSaveLoc
		}
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
	
	//MARK: Managing BBX Programs
	
	public var savedBBXFiles: [String] {
		return self.namesOfsavedFiles(ofType: .BirdBloxProgram)
	}
	
	func getBBXFileLoc(byName filename: String) -> URL {
		let fullFileName = filename + ".bbx"
		let url = self.bbxSaveLoc.appendingPathComponent(fullFileName)
		
		return url
	}
	
	public func getBBXString(byName filename: String) -> String? {
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
		let path = self.getBBXFileLoc(byName: filename).path
		do {
			try FileManager.default.removeItem(atPath: path)
			return true
		} catch {
			return false
		}
	}
	
	public func renameBBXFile(from curName: String, to newName: String) -> Bool {
		let curPath = self.getBBXFileLoc(byName: curName).path
		let newPath = self.getBBXFileLoc(byName: newName).path
		
		do {
			try FileManager.default.moveItem(atPath: curPath, toPath: newPath)
			return true
		} catch {
			return false
		}
	}
	
	//MARK: bbx file names
	
	// Replaces disallowed characters with underscores
	public static func sanitizedName(of name: String) -> String {
		let blackList = ["\\", "/", ":", "*", "?", "<", ">", "|", ".", "\n", "\r", "\0", "\"", "$"]
		let replacement = "_"
		
		var sanitizedString = name
		for bannedChar in blackList {
			sanitizedString = sanitizedString.replacingOccurrences(of: bannedChar,
			                                                       with: replacement)
		}
		
		return sanitizedString
	}
	
	public func bbxNameAvailable(_ name: String) -> Bool {
		return !FileManager.default.fileExists(
			atPath: self.getBBXFileLoc(byName: name).path)
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
	
	
	//MARK: Managing Settings
	
	var settingsDict: NSMutableDictionary?
	
	private func contentsOfSettingsPlist() -> NSMutableDictionary{
		if (!FileManager.default.fileExists(atPath: self.settingsPlistLoc.path)) {
			return NSMutableDictionary()
		}
		return NSMutableDictionary(contentsOfFile: self.settingsPlistLoc.path)!
	}
	
	private func saveSettingsToPlist(_ settings: NSMutableDictionary) {
		settings.write(toFile: self.settingsPlistLoc.path, atomically: true)
	}
	
	
	public func addSetting(_ key: String, value: String) {
		if self.settingsDict == nil {
			self.settingsDict = self.contentsOfSettingsPlist()
		}
		
		self.settingsDict!.setValue(value, forKey: key)
		self.saveSettingsToPlist(self.settingsDict!)
	}
	
	public func getSetting(_ key: String) -> String? {
		if self.settingsDict == nil {
			self.settingsDict = self.contentsOfSettingsPlist()
		}
		if let value = self.settingsDict?.value(forKey: key) {
			return value as? String
		}
		return nil
	}
	
	public func removeSetting(_ key: String) {
		let settings = self.contentsOfSettingsPlist()
		settings.removeObject(forKey: key)
		self.saveSettingsToPlist(settings)
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

