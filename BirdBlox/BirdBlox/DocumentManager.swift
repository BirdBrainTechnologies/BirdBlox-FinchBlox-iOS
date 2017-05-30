//
//  DocumentManager.swift
//  BirdBlox
//
//  Created by birdbrain on 3/21/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import Zip

let documentsPath: URL! = URL(string: NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0])
let fileManager = FileManager.default

func getPathOfBundleFile(filename: String, directory: String) -> String? {
    let mainBundle = Bundle.main
    let path_as_string = mainBundle.bundlePath + "/" + directory + "/" + filename
    if fileManager.fileExists(atPath: path_as_string){
        return path_as_string
    }
    else {
        return nil
    }
}

public func getSoundPath() -> URL{
    let mainBundle = Bundle.main
    let path_as_string = mainBundle.bundlePath + "/SoundClips"
    return URL(fileURLWithPath: path_as_string)
}

public func getSavePath() -> URL{
    return documentsPath.appendingPathComponent("SavedFiles")
}

public func saveStringToFile(_ string: NSString, filename: String) -> Bool{
    let fullFileName = filename + ".bbx"
    let isDir: UnsafeMutablePointer<ObjCBool>? = nil
    if(!fileManager.fileExists(atPath: getSavePath().path, isDirectory: isDir)) {
        do {
            try fileManager.createDirectory(atPath: getSavePath().path, withIntermediateDirectories: false, attributes: nil)
        }
        catch {
            return false
        }
    }
    let path = getSavePath().appendingPathComponent(fullFileName).path
    do {
        try string.write(toFile: path, atomically: true, encoding: String.Encoding.utf8.rawValue)
        return true
    }
    catch {
        return false
    }
}

fileprivate func getAllFiles() -> [String] {
    do {
        let paths = try fileManager.contentsOfDirectory(atPath: getSavePath().path)
        return paths
    } catch {
        return []
    }
    
}

public func getSavedFileURL(_ filename: String) ->URL {
    let fullFileName = filename + ".bbx"
    let path = getSavePath().appendingPathComponent(fullFileName)
    return path
}

public func getSavedFileNames() -> [String]{
    do {
        let paths = try fileManager.contentsOfDirectory(atPath: getSavePath().path)
        var paths2 = paths.map({ (string) -> String in
            return string.replacingOccurrences(of: ".bbx", with: "")
        })
        if let index = paths2.index(of: "autosaveFile") {
            paths2.remove(at: index)
        }
        NSLog(getAllFiles().joined(separator: ", "))
        return paths2
    } catch {
        NSLog(getAllFiles().joined(separator: ", "))
        return []
    }
}

public func getSavedFileByName(_ filename: String) -> NSString {
    do {
        let path = getSavedFileURL(filename).path
        let file: NSString = try NSString(contentsOfFile: path, encoding: String.Encoding.utf8.rawValue)
        return file
    } catch {
        return "File not found"
    }
}

public func deleteFile(_ filename: String) -> Bool {
    let path = getSavedFileURL(filename).path
    do {
        try fileManager.removeItem(atPath: path)
        return true
    } catch {
        return false
    }
}

public func deleteFileAtPath(_ path: String) {
    do {
        try fileManager.removeItem(atPath: path)
    } catch {
        
    }
}

public func renameFile(_ start_filename: String, new_filename: String) -> Bool {
    let startFullFileName = start_filename + ".bbx"
    let startPath = getSavePath().appendingPathComponent(startFullFileName).path
    let newFullFileName = new_filename + ".bbx"
    let newPath = getSavePath().appendingPathComponent(newFullFileName).path
    do {
        try fileManager.moveItem(atPath: startPath, toPath: newPath)
        return true
    } catch {
        return false
    }
}

#if DEBUG
//MARK: Downloading new frontend for debug
//From Tom https://github.com/TomWildenhain/HummingbirdDragAndDrop-/archive/dev.zip
//Semi Stable: https://github.com/BirdBrainTechnologies/HummingbirdDragAndDrop-/archive/dev.zip
let BBTrepoUrl = URL(string:"https://github.com/BirdBrainTechnologies/HummingbirdDragAndDrop-/archive/dev.zip")
let BBTzipPath = documentsPath.appendingPathComponent("temp.zip")
let BBTunzipPath = documentsPath.appendingPathComponent("DragAndDrop")
let BBTFrontendPagePath = BBTunzipPath.appendingPathComponent("HummingbirdDragAndDrop.html")

public func BBTDownloadFrontendUpdate() -> Bool{
	do {
		let zippedData = try NSData(contentsOf: BBTrepoUrl!, options: [NSData.ReadingOptions.uncached])
		zippedData.write(toFile: BBTzipPath.path, atomically: true)
		
		return true;
	}
	catch {
		return false;
	}
}

public func BTTOverwriteFrontendWithDownload() -> Bool {
	do {
		try Zip.unzipFile(BBTzipPath,
		                  destination: BBTunzipPath,
		                  overwrite: true,
						   password: nil,
		                   progress: { (progress) -> () in })
		
		return true
	}
	catch {
		return false
	}
}
#endif

//MARK: managing Settings
public func getSettingsPath() -> URL {
    return documentsPath.appendingPathComponent("Settings.plist")
}

private func getSettings() -> NSMutableDictionary {
    var settings: NSMutableDictionary
    if (!fileManager.fileExists(atPath: getSettingsPath().path)) {
        settings = NSMutableDictionary()
        settings.write(toFile: getSettingsPath().path, atomically: true)
    }
    settings = NSMutableDictionary(contentsOfFile: getSettingsPath().path)!
    return settings
}

private func saveSettings(_ settings: NSMutableDictionary) {
    settings.write(toFile: getSettingsPath().path, atomically: true)
}

public func addSetting(_ key: String, value: String) {
    let settings = getSettings()
    settings.setValue(value, forKey: key)
    saveSettings(settings)
}

public func getSetting(_ key: String) -> String? {
    if let value = getSettings().value(forKey: key) {
        return value as? String
    }
    return nil
}

public func removeSetting(_ key: String) {
    let settings = getSettings()
    settings.removeObject(forKey: key)
    saveSettings(settings)
}
