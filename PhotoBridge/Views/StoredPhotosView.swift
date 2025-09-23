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
    
    @Environment(\.dismiss) private var dismiss
    
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
    @State private var selectedFolderForMove: StoredFolder?
    @State private var showDeleteAlert = false
    @State private var folderToDelete: StoredFolder?
    
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
                } else if isMoving {
                    // Progress view during move
                    VStack(spacing: 20) {
                        Spacer()
                        
                        ZStack {
                            // Background circle
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                                .frame(width: 80, height: 80)
                            
                            // Progress circle
                            Circle()
                                .trim(from: 0, to: uploadProgress)
                                .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 0.5), value: uploadProgress)
                            
                            // Progress text
                            VStack(spacing: 2) {
                                Text("\(Int(uploadProgress * 100))%")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Text("\(completedUploads)/\(totalUploads)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text("Moving photos to Google Drive...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let timeRemaining = estimatedTimeRemaining {
                            Text("Est. \(timeRemaining)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List {
                        ForEach(storageManager.storedFolders) { folder in
                            FolderSelectionRow(
                                folder: folder,
                                isSelected: selectedFolderForMove?.id == folder.id,
                                onSelect: { 
                                    selectedFolderForMove = folder
                                }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    folderToDelete = folder
                                    showDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                
                // Move Button (when folder is selected and not moving)
                if let selectedFolder = selectedFolderForMove, !isMoving {
                    Divider()
                    
                    Button(action: { moveSelectedFolder() }) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.up")
                            Text("Move '\(selectedFolder.name)' to Google Drive")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                    .padding()
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
            .navigationBarBackButtonHidden(true)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            })
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
            .onDisappear {
                // Reset state when sheet is dismissed
                if !showFolderPicker {
                    selectedFolder = nil
                }
            }
        }
        .alert("Move Complete", isPresented: $showSuccess) {
            let successCount = moveResults.filter { $0.success }.count
            let totalCount = moveResults.count
            
            if successCount == totalCount {
                Button("Delete from Camera Roll") {
                    // Photos were already deleted in the move process
                    moveResults.removeAll()
                    selectedFolderForMove = nil
                }
                Button("OK") {
                    moveResults.removeAll()
                    selectedFolderForMove = nil
                }
            } else {
                Button("OK") {
                    moveResults.removeAll()
                    selectedFolderForMove = nil
                }
            }
        } message: {
            let successCount = moveResults.filter { $0.success }.count
            let totalCount = moveResults.count
            
            if successCount == totalCount {
                Text("\(totalCount) photos moved successfully! They have been deleted from your camera roll.")
            } else {
                Text("\(successCount) of \(totalCount) photos moved successfully. No photos were deleted from your camera roll.")
            }
        }
        .alert("Delete Folder", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let folder = folderToDelete {
                    deleteFolder(folder)
                }
                folderToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                folderToDelete = nil
            }
        } message: {
            if let folder = folderToDelete {
                Text("Are you sure you want to delete the '\(folder.name)' folder? This will remove \(folder.photoCount) photos from storage and clear their folder colors, but won't delete them from your camera roll.")
            }
        }
    }
    
    // MARK: - Actions
    
    private func moveSelectedFolder() {
        guard let selectedFolder = selectedFolderForMove else { return }
        folderToMove = selectedFolder
        showFolderPicker = true
    }
    
    private func deleteFolder(_ folder: StoredFolder) {
        storageManager.clearFolder(folder.name)
        
        // Clear selection if this folder was selected
        if selectedFolderForMove?.id == folder.id {
            selectedFolderForMove = nil
        }
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

struct FolderSelectionRow: View {
    let folder: StoredFolder
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
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
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CreateFolderView: View {
    @ObservedObject var storageManager: LocalStorageManager
    @ObservedObject var photoManager: PhotoLibraryManager
    
    let onDismiss: () -> Void
    let onStore: () -> Void
    
    @State private var folderName = ""
    @State private var selectedColor = StoredPhoto.FolderColor.green
    @State private var showDuplicateNameAlert = false
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
                    // Existing folders section
                    if !storageManager.storedFolders.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add to Existing Folder")
                                .font(.headline)
                            
                            List {
                                ForEach(storageManager.storedFolders) { folder in
                                    HStack {
                                        Image(systemName: folder.color.icon)
                                            .font(.title3)
                                            .foregroundColor(folder.color.color)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(folder.name)
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
                                    .padding(.vertical, 4)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedExistingFolder = folder
                                        folderName = "" // Clear new folder name
                                    }
                                }
                            }
                            .frame(height: 120)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                    }
                    
                    // OR Create new folder section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OR Create New Folder")
                            .font(.headline)
                        
                        // Folder name input
                        TextField("Enter folder name", text: $folderName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onTapGesture {
                                selectedExistingFolder = nil // Clear existing folder selection
                            }
                        
                        // Color selection (only show if creating new folder)
                        if selectedExistingFolder == nil {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                                ForEach(StoredPhoto.FolderColor.allCases, id: \.self) { color in
                                    ColorOptionView(
                                        color: color,
                                        isSelected: selectedColor == color
                                    ) {
                                        selectedColor = color
                                        selectedExistingFolder = nil // Clear existing folder selection
                                    }
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
                        Image(systemName: selectedExistingFolder != nil ? "folder.fill" : "folder.badge.plus")
                        Text(selectedExistingFolder != nil ? "Add to '\(selectedExistingFolder!.name)'" : "Create Folder")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canStorePhotos ? (selectedExistingFolder != nil ? Color.orange : Color.blue) : Color.gray)
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
            .alert("Folder Name Already Exists", isPresented: $showDuplicateNameAlert) {
                Button("OK") { }
            } message: {
                Text("A folder with this name already exists. Please choose a different name.")
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
            
            guard storageManager.isFolderNameUnique(trimmedName) else {
                showDuplicateNameAlert = true
                return
            }
            
            storageManager.storePhotos(assetIds, in: trimmedName, with: selectedColor)
        }
        
        // Dismiss
        dismiss()
        onDismiss()
        
        // Trigger store workflow
        onStore()
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
