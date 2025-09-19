//
//  GoogleDriveManager.swift
//  PhotoBridge
//
//  Created by Brock Denton on 9/19/25.
//

import Foundation
import SwiftUI

struct GoogleDriveFolder: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let parentId: String?
    
    var path: String {
        return name
    }
}

struct UploadResult {
    let success: Bool
    let fileName: String
    let error: Error?
    let fileId: String?
}

struct DriveFile: Codable {
    let id: String
    let name: String
    let mimeType: String
    let size: String?
    let parents: [String]?
}

struct DriveFileList: Codable {
    let files: [DriveFile]
    let nextPageToken: String?
}

@MainActor
class GoogleDriveManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var folders: [GoogleDriveFolder] = []
    @Published var selectedFolder: GoogleDriveFolder?
    @Published var uploadProgress: [String: Double] = [:]
    @Published var isUploading = false
    
    private let authManager = GoogleAuthManager()
    private let lastFolderKey = "last_used_folder_id"
    
    init() {
        setupAuthObserver()
        loadLastUsedFolder()
    }
    
    private func setupAuthObserver() {
        Task { @MainActor in
            for await _ in NotificationCenter.default.notifications(named: .authStatusChanged) {
                isAuthenticated = authManager.isAuthenticated
                if isAuthenticated {
                    await loadFolders()
                } else {
                    folders = []
                    selectedFolder = nil
                }
            }
        }
    }
    
    private func loadLastUsedFolder() {
        if let folderId = UserDefaults.standard.string(forKey: lastFolderKey),
           let folder = folders.first(where: { $0.id == folderId }) {
            selectedFolder = folder
        }
    }
    
    func authenticate() async {
        do {
            try await authManager.startAuthentication()
            isAuthenticated = authManager.isAuthenticated
            if isAuthenticated {
                await loadFolders()
            }
        } catch {
            print("Authentication failed: \(error)")
        }
    }
    
    func loadFolders() async {
        guard let accessToken = authManager.accessToken else { return }
        
        var components = URLComponents(string: "\(GoogleAPIConfig.driveAPIBase)/files")!
        components.queryItems = [
            URLQueryItem(name: "q", value: "mimeType='application/vnd.google-apps.folder' and trashed=false"),
            URLQueryItem(name: "fields", value: "files(id,name,parents)"),
            URLQueryItem(name: "orderBy", value: "name")
        ]
        
        guard let url = components.url else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(DriveFileList.self, from: data)
            
            let driveFolders = response.files.map { file in
                GoogleDriveFolder(
                    id: file.id,
                    name: file.name,
                    parentId: file.parents?.first
                )
            }
            
            // Add root folder
            let rootFolder = GoogleDriveFolder(id: "root", name: "My Drive", parentId: nil)
            folders = [rootFolder] + driveFolders
            
            loadLastUsedFolder()
            
        } catch {
            print("Failed to load folders: \(error)")
        }
    }
    
    func selectFolder(_ folder: GoogleDriveFolder) {
        selectedFolder = folder
        UserDefaults.standard.set(folder.id, forKey: lastFolderKey)
    }
    
    func uploadFile(data: Data, fileName: String) async -> UploadResult {
        guard let folder = selectedFolder,
              let accessToken = authManager.accessToken else {
            return UploadResult(success: false, fileName: fileName, error: NSError(domain: "NoFolderSelected", code: 0), fileId: nil)
        }
        
        uploadProgress[fileName] = 0.0
        isUploading = true
        
        do {
            // Create file metadata
            let metadata = [
                "name": fileName,
                "parents": [folder.id]
            ]
            
            let metadataData = try JSONSerialization.data(withJSONObject: metadata)
            
            // Create multipart upload
            let boundary = "Boundary-\(UUID().uuidString)"
            var body = Data()
            
            // Add metadata part
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
            body.append(metadataData)
            body.append("\r\n".data(using: .utf8)!)
            
            // Add file data part
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
            
            // Create upload URL
            var components = URLComponents(string: "\(GoogleAPIConfig.uploadAPIBase)/files")!
            components.queryItems = [
                URLQueryItem(name: "uploadType", value: "multipart"),
                URLQueryItem(name: "fields", value: "id,name")
            ]
            
            guard let url = components.url else {
                throw NSError(domain: "InvalidURL", code: -1)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
            
            // Simulate progress updates
            let progressTask = Task {
                for progress in stride(from: 0.1, through: 0.9, by: 0.1) {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    await MainActor.run {
                        uploadProgress[fileName] = progress
                    }
                }
            }
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            progressTask.cancel()
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NSError(domain: "UploadFailed", code: (response as? HTTPURLResponse)?.statusCode ?? -1)
            }
            
            let uploadedFile = try JSONDecoder().decode(DriveFile.self, from: responseData)
            
            await MainActor.run {
                uploadProgress[fileName] = 1.0
                uploadProgress.removeValue(forKey: fileName)
                isUploading = uploadProgress.isEmpty
            }
            
            return UploadResult(success: true, fileName: fileName, error: nil, fileId: uploadedFile.id)
            
        } catch {
            await MainActor.run {
                uploadProgress.removeValue(forKey: fileName)
                isUploading = uploadProgress.isEmpty
            }
            
            return UploadResult(success: false, fileName: fileName, error: error, fileId: nil)
        }
    }
    
    func verifyUpload(fileName: String, fileId: String) async -> Bool {
        guard let accessToken = authManager.accessToken else { return false }
        
        var components = URLComponents(string: "\(GoogleAPIConfig.driveAPIBase)/files/\(fileId)")!
        components.queryItems = [
            URLQueryItem(name: "fields", value: "id,name,size")
        ]
        
        guard let url = components.url else { return false }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return httpResponse.statusCode == 200
        } catch {
            print("Verification failed: \(error)")
            return false
        }
    }
    
    func signOut() {
        authManager.signOut()
        isAuthenticated = false
        folders = []
        selectedFolder = nil
        uploadProgress = [:]
        isUploading = false
        UserDefaults.standard.removeObject(forKey: lastFolderKey)
    }
}

extension Notification.Name {
    static let authStatusChanged = Notification.Name("authStatusChanged")
}
