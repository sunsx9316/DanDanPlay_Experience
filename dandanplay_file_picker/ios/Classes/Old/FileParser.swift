//
//  FileParser.swift
//  FileBrowser
//
//  Created by Roy Marmelstein on 13/02/2016.
//  Copyright © 2016 Roy Marmelstein. All rights reserved.
//

import Foundation
import CoreServices

class FileParser {
    
    static let sharedInstance = FileParser()
    
    var documentTypes: [String]?
    
    let fileManager = FileManager.default
    
    func documentsURL() -> URL {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0] as URL
    }
    
    func filesForDirectory(_ directoryPath: URL) -> [FBFile]  {
        var files = [FBFile]()
        var filePaths = [URL]()
        // Get contents
        do  {
            filePaths = try self.fileManager.contentsOfDirectory(at: directoryPath, includingPropertiesForKeys: [], options: [.skipsHiddenFiles])
        } catch {
            return files
        }
        // Parse
        for filePath in filePaths {
            let file = FBFile(filePath: filePath)
            
            if let fileExtension = file.fileExtension as CFString?,
                let fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension, nil), let documentTypes = self.documentTypes {
                
                let result = documentTypes.contains { (str) -> Bool in
                    return UTTypeConformsTo(fileUTI.takeRetainedValue(), str as CFString)
                }
                
                if !result {
                    continue
                }
            }
            
            if file.displayName.isEmpty == false {
                files.append(file)
            }
        }
        // Sort
        files = files.sorted(){$0.displayName < $1.displayName}
        return files
    }

}
