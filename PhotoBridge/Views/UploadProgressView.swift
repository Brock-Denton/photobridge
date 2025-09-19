//
//  UploadProgressView.swift
//  PhotoBridge
//
//  Created by Brock Denton on 9/19/25.
//

import SwiftUI

struct UploadProgressView: View {
    @ObservedObject var driveManager: GoogleDriveManager
    @ObservedObject var photoManager: PhotoLibraryManager
    
    @State private var uploadResults: [UploadResult] = []
    @State private var isUploading = false
    @State private var showResults = false
    @State private var showFolderPicker = false
    
    var selectedCount: Int {
        photoManager.selectedAssets.count
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if selectedCount > 0 {
                HStack {
                    Text("\(selectedCount) item\(selectedCount == 1 ? "" : "s") selected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Clear Selection") {
                        photoManager.clearSelection()
                    }
                    .font(.caption)
                }
                
                Button(action: { showFolderPicker = true }) {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                        Text("Move")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canMove ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(!canMove)
                
                if isUploading {
                    UploadProgressDetailsView(
                        driveManager: driveManager,
                        photoManager: photoManager
                    )
                }
            }
        }
        .sheet(isPresented: $showFolderPicker) {
            MoveToFolderView(
                driveManager: driveManager,
                photoManager: photoManager,
                onMove: { folder in
                    showFolderPicker = false
                    startMove(to: folder)
                }
            )
        }
        .alert("Move Complete", isPresented: $showResults) {
            Button("OK") {
                uploadResults.removeAll()
                photoManager.clearSelection()
            }
        } message: {
            let successCount = uploadResults.filter { $0.success }.count
            let totalCount = uploadResults.count
            
            if successCount == totalCount {
                Text("\(totalCount) photos deleted and moved to Drive!")
            } else {
                Text("\(successCount) of \(totalCount) photos moved successfully. No photos were deleted.")
            }
        }
    }
    
    private var canMove: Bool {
        selectedCount > 0 && 
        driveManager.isAuthenticated &&
        !isUploading
    }
    
    private func startMove(to folder: GoogleDriveFolder) {
        guard canMove else { return }
        
        isUploading = true
        uploadResults.removeAll()
        
        Task {
            let selectedAssets = photoManager.getSelectedAssets()
            var allSuccessful = true
            
            // Upload each file to the selected folder
            for asset in selectedAssets {
                guard let data = await photoManager.getAssetData(for: asset) else {
                    let result = UploadResult(success: false, fileName: photoManager.getAssetFileName(for: asset), error: NSError(domain: "NoData", code: 0), fileId: nil)
                    await MainActor.run {
                        uploadResults.append(result)
                        allSuccessful = false
                    }
                    continue
                }
                
                let fileName = photoManager.getAssetFileName(for: asset)
                let uploadResult = await driveManager.uploadFileToFolder(data: data, fileName: fileName, folderId: folder.id)
                
                await MainActor.run {
                    uploadResults.append(uploadResult)
                    if !uploadResult.success {
                        allSuccessful = false
                    }
                }
            }
            
            // Delete originals only if all uploads were successful
            if allSuccessful {
                do {
                    try await photoManager.deleteSelectedAssets()
                } catch {
                    print("Failed to delete assets: \(error)")
                }
            }
            
            await MainActor.run {
                isUploading = false
                showResults = true
            }
        }
    }
}

struct MoveToFolderView: View {
    @ObservedObject var driveManager: GoogleDriveManager
    @ObservedObject var photoManager: PhotoLibraryManager
    let onMove: (GoogleDriveFolder) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    
    var selectedCount: Int {
        photoManager.selectedAssets.count
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Text("Move \(selectedCount) photo\(selectedCount == 1 ? "" : "s")")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Select a folder to move your photos to Google Drive")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                Divider()
                
                // Folder list
                List {
                    // Create new folder option
                    Button(action: { showCreateFolder = true }) {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                                .foregroundColor(.blue)
                            Text("Create New Folder")
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Existing folders
                    ForEach(driveManager.folders) { folder in
                        Button(action: { onMove(folder) }) {
                            HStack {
                                Image(systemName: folder.id == "root" ? "house" : "folder")
                                    .foregroundColor(.blue)
                                Text(folder.name)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .navigationTitle("Select Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Create New Folder", isPresented: $showCreateFolder) {
            TextField("Folder Name", text: $newFolderName)
            Button("Create") {
                createNewFolder()
            }
            Button("Cancel", role: .cancel) {
                newFolderName = ""
            }
        } message: {
            Text("Enter a name for the new folder")
        }
    }
    
    private func createNewFolder() {
        guard !newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        Task {
            // Create folder in Google Drive
            if let folder = await driveManager.createFolder(name: newFolderName) {
                await MainActor.run {
                    onMove(folder)
                }
            }
        }
        
        newFolderName = ""
    }
}

struct UploadProgressDetailsView: View {
    @ObservedObject var driveManager: GoogleDriveManager
    @ObservedObject var photoManager: PhotoLibraryManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Upload Progress")
                .font(.headline)
            
            if driveManager.uploadProgress.isEmpty {
                ProgressView("Preparing upload...")
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(Array(driveManager.uploadProgress.keys.sorted()), id: \.self) { fileName in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(fileName)
                            .font(.caption)
                            .lineLimit(1)
                        
                        ProgressView(value: driveManager.uploadProgress[fileName])
                            .progressViewStyle(LinearProgressViewStyle())
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
