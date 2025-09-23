//
//  LocalStorageManager.swift
//  PhotoBridge
//
//  Created by Brock Denton on 9/19/25.
//

import Foundation
import SwiftUI
import Photos

struct StoredPhoto: Identifiable, Codable {
    let id: String
    let assetId: String
    let folderName: String
    let folderColor: FolderColor
    let dateStored: Date
    
    enum FolderColor: String, CaseIterable, Codable {
        case green = "green"
        case blue = "blue"
        case purple = "purple"
        case orange = "orange"
        case red = "red"
        case yellow = "yellow"
        case teal = "teal"
        case pink = "pink"
        case indigo = "indigo"
        case brown = "brown"
        
        var color: Color {
            switch self {
            case .green: return .green
            case .blue: return .blue
            case .purple: return .purple
            case .orange: return .orange
            case .red: return .red
            case .yellow: return .yellow
            case .teal: return .teal
            case .pink: return .pink
            case .indigo: return .indigo
            case .brown: return .brown
            }
        }
        
        var icon: String {
            switch self {
            case .green: return "folder.fill"
            case .blue: return "folder.fill"
            case .purple: return "folder.fill"
            case .orange: return "folder.fill"
            case .red: return "folder.fill"
            case .yellow: return "folder.fill"
            case .teal: return "folder.fill"
            case .pink: return "folder.fill"
            case .indigo: return "folder.fill"
            case .brown: return "folder.fill"
            }
        }
    }
}

struct StoredFolder: Identifiable, Codable {
    let id: String
    let name: String
    let color: StoredPhoto.FolderColor
    let dateCreated: Date
    let photoCount: Int
    
    var displayName: String {
        return "\(name) (\(photoCount) photos)"
    }
}

@MainActor
class LocalStorageManager: ObservableObject {
    @Published var storedPhotos: [StoredPhoto] = []
    @Published var storedFolders: [StoredFolder] = []
    
    private let storedPhotosKey = "stored_photos"
    private let storedFoldersKey = "stored_folders"
    
    init() {
        loadStoredData()
        updateFoldersFromPhotos()
    }
    
    // MARK: - Data Persistence
    
    private func saveStoredData() {
        if let photosData = try? JSONEncoder().encode(storedPhotos) {
            UserDefaults.standard.set(photosData, forKey: storedPhotosKey)
        }
        if let foldersData = try? JSONEncoder().encode(storedFolders) {
            UserDefaults.standard.set(foldersData, forKey: storedFoldersKey)
        }
    }
    
    private func loadStoredData() {
        if let photosData = UserDefaults.standard.data(forKey: storedPhotosKey),
           let photos = try? JSONDecoder().decode([StoredPhoto].self, from: photosData) {
            storedPhotos = photos
        }
        
        if let foldersData = UserDefaults.standard.data(forKey: storedFoldersKey),
           let folders = try? JSONDecoder().decode([StoredFolder].self, from: foldersData) {
            storedFolders = folders
        }
    }
    
    // MARK: - Photo Management
    
    func storePhotos(_ assetIds: [String], in folderName: String, with color: StoredPhoto.FolderColor) {
        let newPhotos = assetIds.map { assetId in
            StoredPhoto(
                id: UUID().uuidString,
                assetId: assetId,
                folderName: folderName,
                folderColor: color,
                dateStored: Date()
            )
        }
        
        storedPhotos.append(contentsOf: newPhotos)
        updateFoldersFromPhotos()
        saveStoredData()
        
        print("📁 Stored \(newPhotos.count) photos in '\(folderName)' folder")
    }
    
    func isFolderNameUnique(_ folderName: String) -> Bool {
        return !storedFolders.contains { $0.name.lowercased() == folderName.lowercased() }
    }
    
    func removePhotosFromStorage(_ assetIds: [String]) {
        storedPhotos.removeAll { photo in
            assetIds.contains(photo.assetId)
        }
        updateFoldersFromPhotos()
        saveStoredData()
        
        print("📁 Removed \(assetIds.count) photos from storage")
    }
    
    func clearFolder(_ folderName: String) {
        storedPhotos.removeAll { photo in
            photo.folderName == folderName
        }
        updateFoldersFromPhotos()
        saveStoredData()
        
        print("📁 Cleared folder '\(folderName)'")
    }
    
    // MARK: - Folder Management
    
    private func updateFoldersFromPhotos() {
        let folderGroups = Dictionary(grouping: storedPhotos) { $0.folderName }
        
        storedFolders = folderGroups.map { (folderName, photos) in
            let firstPhoto = photos.first!
            return StoredFolder(
                id: folderName,
                name: folderName,
                color: firstPhoto.folderColor,
                dateCreated: photos.map { $0.dateStored }.min() ?? Date(),
                photoCount: photos.count
            )
        }.sorted { $0.dateCreated > $1.dateCreated }
    }
    
    func getPhotosInFolder(_ folderName: String) -> [StoredPhoto] {
        return storedPhotos.filter { $0.folderName == folderName }
    }
    
    func getPhotoIdsInFolder(_ folderName: String) -> [String] {
        return getPhotosInFolder(folderName).map { $0.assetId }
    }
    
    // MARK: - Photo Status Checking
    
    func isPhotoStored(_ assetId: String) -> Bool {
        return storedPhotos.contains { $0.assetId == assetId }
    }
    
    func getPhotoFolder(_ assetId: String) -> StoredFolder? {
        guard let photo = storedPhotos.first(where: { $0.assetId == assetId }) else {
            return nil
        }
        return storedFolders.first { $0.name == photo.folderName }
    }
    
    func getPhotoFolderColor(_ assetId: String) -> StoredPhoto.FolderColor? {
        return storedPhotos.first(where: { $0.assetId == assetId })?.folderColor
    }
    
    // MARK: - Utility Methods
    
    func getAllStoredAssetIds() -> [String] {
        return storedPhotos.map { $0.assetId }
    }
    
    func getUniqueFolderNames() -> [String] {
        return Array(Set(storedPhotos.map { $0.folderName })).sorted()
    }
    
    func getAvailableColors() -> [StoredPhoto.FolderColor] {
        let usedColors = Set(storedFolders.map { $0.color })
        return StoredPhoto.FolderColor.allCases.filter { !usedColors.contains($0) }
    }
}
