//
//  StoredPhotosView.swift
//  PhotoBridge
//
//  Created by Brock Denton on 9/19/25.
//

import SwiftUI
import Photos

struct StoredPhotosView: View {
    @ObservedObject var storageManager: LocalStorageManager
    @ObservedObject var photoManager: PhotoLibraryManager
    @ObservedObject var driveManager: GoogleDriveManager
    
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    @State private var selectedFolderColor = StoredPhoto.FolderColor.green
    @State private var showFolderPicker = false
    @State private var selectedFolder: GoogleDriveFolder?
    @State private var isMoving = false
    @State private var moveResults: [UploadResult] = []
    @State private var showSuccess = false
    @State private var uploadProgress: Double = 0.0
    @State private var completedUploads: Int = 0
    @State private var totalUploads: Int = 0
    @State private var estimatedTimeRemaining: String?
    @State private var uploadStartTime: Date?
    @State private var folderToMove: StoredFolder?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Text("Stored Photos")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Organized folders ready to move to Google Drive")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                Divider()
                
                // Folder List
                if storageManager.storedFolders.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("No stored folders yet")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Text("Go back to Photos tab and use 'Store' to organize your photos into folders")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(storageManager.storedFolders) { folder in
                            FolderRowView(
                                folder: folder,
                                onMoveAll: { moveFolder(folder) },
                                onViewPhotos: { viewFolderPhotos(folder) },
                                onDeleteFolder: { deleteFolder(folder) }
                            )
                        }
                    }
                }
                
                // Create New Folder Button
                if !storageManager.storedFolders.isEmpty {
                    Divider()
                    
                    Button(action: { showCreateFolder = true }) {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                            Text("Create New Folder")
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding()
                }
            }
            .navigationTitle("Stored Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        // This will be handled by the parent view
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateFolder) {
            CreateFolderView(
                storageManager: storageManager,
                photoManager: photoManager,
                onDismiss: { showCreateFolder = false }
            )
        }
        .sheet(isPresented: $showFolderPicker) {
            FolderPickerView(
                driveManager: driveManager,
                selectedFolder: $selectedFolder,
                onConfirm: { folder in
                    selectedFolder = folder
                    showFolderPicker = false
                    startMoveFolder(to: folder)
                }
            )
        }
        .alert("Move Complete", isPresented: $showSuccess) {
            Button("OK") {
                moveResults.removeAll()
            }
        } message: {
            let successCount = moveResults.filter { $0.success }.count
            let totalCount = moveResults.count
            
            if successCount == totalCount {
                Text("\(totalCount) photos moved successfully!")
            } else {
                Text("\(successCount) of \(totalCount) photos moved successfully.")
            }
        }
    }
    
    // MARK: - Actions
    
    private func moveFolder(_ folder: StoredFolder) {
        // Store the folder to move for later use
        folderToMove = folder
        showFolderPicker = true
    }
    
    private func viewFolderPhotos(_ folder: StoredFolder) {
        // This could show a detailed view of photos in the folder
        print("Viewing photos in folder: \(folder.name)")
    }
    
    private func deleteFolder(_ folder: StoredFolder) {
        storageManager.clearFolder(folder.name)
    }
    
    private func startMoveFolder(to googleDriveFolder: GoogleDriveFolder) {
        guard let folder = folderToMove else { return }
        
        isMoving = true
        moveResults.removeAll()
        uploadStartTime = Date()
        
        let assetIds = storageManager.getPhotoIdsInFolder(folder.name)
        let assets = photoManager.getAssetsByIds(assetIds)
        totalUploads = assets.count
        completedUploads = 0
        uploadProgress = 0.0
        
        Task {
            var allSuccessful = true
            
            // Upload each file to the selected Google Drive folder
            for (index, asset) in assets.enumerated() {
                guard let data = await photoManager.getAssetData(for: asset) else {
                    let result = UploadResult(success: false, fileName: photoManager.getAssetFileName(for: asset), error: NSError(domain: "NoData", code: 0), fileId: nil)
                    await MainActor.run {
                        moveResults.append(result)
                        allSuccessful = false
                        completedUploads += 1
                        uploadProgress = Double(completedUploads) / Double(totalUploads)
                        updateTimeEstimation()
                    }
                    continue
                }
                
                let fileName = photoManager.getAssetFileName(for: asset)
                let uploadResult = await driveManager.uploadFileToFolder(data: data, fileName: fileName, folderId: googleDriveFolder.id)
                
                await MainActor.run {
                    moveResults.append(uploadResult)
                    completedUploads += 1
                    uploadProgress = Double(completedUploads) / Double(totalUploads)
                    updateTimeEstimation()
                    
                    if !uploadResult.success {
                        allSuccessful = false
                    }
                }
            }
            
            // Delete originals only if all uploads were successful
            if allSuccessful {
                do {
                    try await photoManager.deleteSelectedAssets()
                    // Clear the folder from storage
                    storageManager.clearFolder(folder.name)
                } catch {
                    print("Failed to delete assets: \(error)")
                }
            }
            
            await MainActor.run {
                isMoving = false
                showSuccess = true
                uploadStartTime = nil
                estimatedTimeRemaining = nil
                folderToMove = nil
            }
        }
    }
    
    private func updateTimeEstimation() {
        guard let startTime = uploadStartTime, completedUploads > 0 else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let averageTimePerFile = elapsed / Double(completedUploads)
        let remainingFiles = totalUploads - completedUploads
        let estimatedRemainingSeconds = averageTimePerFile * Double(remainingFiles)
        
        if estimatedRemainingSeconds < 60 {
            estimatedTimeRemaining = "\(Int(estimatedRemainingSeconds))s"
        } else {
            let minutes = Int(estimatedRemainingSeconds / 60)
            estimatedTimeRemaining = "\(minutes)m"
        }
    }
}

struct FolderRowView: View {
    let folder: StoredFolder
    let onMoveAll: () -> Void
    let onViewPhotos: () -> Void
    let onDeleteFolder: () -> Void
    
    @State private var showDeleteAlert = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // Folder icon with color
                Image(systemName: folder.color.icon)
                    .font(.title2)
                    .foregroundColor(folder.color.color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(folder.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(folder.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Created \(folder.dateCreated, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    Button(action: onViewPhotos) {
                        Image(systemName: "eye")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: onMoveAll) {
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(.green)
                    }
                    
                    Button(action: { showDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .alert("Delete Folder", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                onDeleteFolder()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete the '\(folder.name)' folder? This will remove \(folder.photoCount) photos from storage but won't delete them from your camera roll.")
        }
    }
}

struct CreateFolderView: View {
    @ObservedObject var storageManager: LocalStorageManager
    @ObservedObject var photoManager: PhotoLibraryManager
    
    let onDismiss: () -> Void
    
    @State private var folderName = ""
    @State private var selectedColor = StoredPhoto.FolderColor.green
    @State private var selectedExistingFolder: StoredFolder?
    @Environment(\.dismiss) private var dismiss
    
    var selectedCount: Int {
        photoManager.selectedAssets.count
    }
    
    var canStorePhotos: Bool {
        return selectedExistingFolder != nil || !folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Create New Folder")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Store \(selectedCount) selected photos in a new folder")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                VStack(spacing: 16) {
                    // Add to existing folder section
                    if !storageManager.storedFolders.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add to Existing Folder")
                                .font(.headline)
                            
                            ForEach(storageManager.storedFolders) { folder in
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(folder.color.color)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(folder.displayName)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Text("\(folder.photoCount) photos")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedExistingFolder?.id == folder.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedExistingFolder?.id == folder.id ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                )
                                .onTapGesture {
                                    if selectedExistingFolder?.id == folder.id {
                                        selectedExistingFolder = nil
                                    } else {
                                        selectedExistingFolder = folder
                                        folderName = "" // Clear new folder name
                                    }
                                }
                            }
                        }
                        
                        Divider()
                    }
                    
                    // Folder name input (for new folders)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedExistingFolder == nil ? "Folder Name" : "Or Create New Folder")
                            .font(.headline)
                        
                        TextField("Enter folder name", text: $folderName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(selectedExistingFolder != nil)
                    }
                    
                    // Color selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Folder Color")
                            .font(.headline)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                            ForEach(StoredPhoto.FolderColor.allCases, id: \.self) { color in
                                ColorOptionView(
                                    color: color,
                                    isSelected: selectedColor == color
                                ) {
                                    selectedColor = color
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Store button
                Button(action: storePhotos) {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                        Text(selectedExistingFolder != nil ? "Add to Folder" : "Create & Store")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canStorePhotos ? Color.blue : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!canStorePhotos)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func storePhotos() {
        let assetIds = photoManager.getSelectedAssetIds()
        
        if let existingFolder = selectedExistingFolder {
            // Add to existing folder
            storageManager.storePhotos(assetIds, in: existingFolder.name, with: existingFolder.color)
        } else {
            // Create new folder
            let trimmedName = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { return }
            
            storageManager.storePhotos(assetIds, in: trimmedName, with: selectedColor)
        }
        
        // Clear selection
        photoManager.clearSelection()
        
        // Dismiss
        dismiss()
        onDismiss()
    }
}

struct ColorOptionView: View {
    let color: StoredPhoto.FolderColor
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(color.color)
                    .frame(width: 40, height: 40)
                
                if isSelected {
                    Circle()
                        .stroke(Color.primary, lineWidth: 2)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "checkmark")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    StoredPhotosView(
        storageManager: LocalStorageManager(),
        photoManager: PhotoLibraryManager(),
        driveManager: GoogleDriveManager()
    )
}
