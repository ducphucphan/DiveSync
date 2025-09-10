//
//  DivePhotoManager.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 7/28/25.
//

import UIKit

class DivePhotoManager {
    
    static let shared = DivePhotoManager()
    
    private init() {}
    
    // MARK: - Directory Helpers

    private func diveFolderPath(modelID: String, serialNo: String, diveID: Int) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent("DivePhotos/\(modelID)_\(serialNo)_\(diveID)")
    }
    
    private func ensureDiveFolderExists(modelID: String, serialNo: String, diveID: Int) throws -> URL {
        let folder = diveFolderPath(modelID: modelID, serialNo: serialNo, diveID: diveID)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
        }
        return folder
    }
    
    // MARK: - Add Photo

    func addPhoto(_ image: UIImage, diveID: Int, modelID: String, serialNo: String) throws {
        let folder = try ensureDiveFolderExists(modelID: modelID, serialNo: serialNo, diveID: diveID)
        
        // Unique filename based on timestamp
        let filename = "photo_\(Int(Date().timeIntervalSince1970)).jpg"
        let filepath = folder.appendingPathComponent(filename)
        
        // Save image as JPEG
        if let data = image.jpegData(compressionQuality: 0.9) {
            try data.write(to: filepath)
            
            // Save to database
            _ = DatabaseManager.shared.insertIntoTable(tableName: "DivePhotos", params: ["DiveID": diveID, "FileName": filename])
        } else {
            throw NSError(domain: "DivePhotoManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not convert image to JPEG"])
        }
    }
    
    // MARK: - Load Photos

    func loadPhotoPaths(forDiveID diveID: Int, modelID: String, serialNo: String) throws -> [URL] {
        
        guard let rows = DatabaseManager.shared.runSQL("SELECT FileName FROM DivePhotos WHERE DiveID = ?", arguments: [diveID]), rows.count > 0 else {
            return []
        }
        
        let folder = diveFolderPath(modelID: modelID, serialNo: serialNo, diveID: diveID)
        return rows.compactMap { row in
            let filename = row.string(for: "filename")
            return folder.appendingPathComponent(filename)
        }
    }
    
    // MARK: - Delete Photo

    func deletePhoto(fileName: String, diveID: Int, modelID: String, serialNo: String) throws {
        let folder = diveFolderPath(modelID: modelID, serialNo: serialNo, diveID: diveID)
        let filepath = folder.appendingPathComponent(fileName)
        
        // Delete from file system
        if FileManager.default.fileExists(atPath: filepath.path) {
            try FileManager.default.removeItem(at: filepath)
        }
        
        // Delete from database
        DatabaseManager.shared.deleteRows(from: "DivePhotos", where: "DiveID = ? AND FileName = ?", arguments: [diveID, fileName])
    }
    
    // MARK: - Delete All Photos of Dive

    func deleteAllPhotos(forDiveID diveID: Int, modelID: String, serialNo: String) throws {
        let folder = diveFolderPath(modelID: modelID, serialNo: serialNo, diveID: diveID)
        
        if FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.removeItem(at: folder)
        }
        
        DatabaseManager.shared.deleteRows(from: "DivePhotos", where: "DiveID = ?", arguments: [diveID])
    }
}

