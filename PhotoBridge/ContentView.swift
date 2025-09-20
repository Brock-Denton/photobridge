//
//  ContentView.swift
//  PhotoBridge
//
//  Created by Brock Denton on 9/19/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var photoManager = PhotoLibraryManager()
    @StateObject private var driveManager = GoogleDriveManager()
    
    var body: some View {
        NavigationView {
            Group {
                if !driveManager.isAuthenticated {
                    // Home page with login
                    HomePageView(driveManager: driveManager)
                } else if photoManager.authorizationStatus == .notDetermined || photoManager.authorizationStatus == .denied {
                    // Photo access request
                    PhotoAccessView(photoManager: photoManager)
                } else {
                    // Main photo selection and move workflow
                    PhotoSelectionView(photoManager: photoManager, driveManager: driveManager)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct HomePageView: View {
    @ObservedObject var driveManager: GoogleDriveManager
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // App icon and title
            VStack(spacing: 20) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("PhotoBridge")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Move your photos from camera roll to Google Drive")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Login button
            Button(action: {
                Task {
                    await driveManager.authenticate()
                }
            }) {
                HStack {
                    Image(systemName: "icloud.and.arrow.up")
                    Text("Sign In to Google Drive")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
        .background(Color(.systemBackground))
    }
}

struct PhotoAccessView: View {
    @ObservedObject var photoManager: PhotoLibraryManager
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Photo Access Required")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("PhotoBridge needs access to your photo library to help you move photos to Google Drive.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            Button(action: {
                Task {
                    await photoManager.requestAuthorization()
                }
            }) {
                HStack {
                    Image(systemName: "checkmark.circle")
                    Text("Grant Photo Access")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
        .background(Color(.systemBackground))
    }
}

struct PhotoSelectionView: View {
    @ObservedObject var photoManager: PhotoLibraryManager
    @ObservedObject var driveManager: GoogleDriveManager
    
    @State private var showFolderPicker = false
    @State private var selectedFolder: GoogleDriveFolder?
    @State private var isMoving = false
    @State private var showSuccess = false
    @State private var moveResults: [UploadResult] = []
    
    var selectedCount: Int {
        photoManager.selectedAssets.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Photos to Move")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Sign Out") {
                    driveManager.signOut()
                }
                .font(.caption)
                .foregroundColor(.red)
            }
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            // Photo grid
            if photoManager.isLoading {
                Spacer()
                ProgressView("Loading photos...")
                Spacer()
            } else {
                PhotoGridView(photoManager: photoManager)
            }
            
            Divider()
            
            // Bottom controls
            VStack(spacing: 16) {
                if isMoving {
                    // Progress indicator during upload
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("Moving photos to Google Drive...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Please wait while your photos are being uploaded")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                } else if selectedCount > 0 {
                    HStack {
                        Text("\(selectedCount) photo\(selectedCount == 1 ? "" : "s") selected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Clear") {
                            photoManager.clearSelection()
                        }
                        .font(.caption)
                    }
                    
                    Button(action: { showFolderPicker = true }) {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                            Text("Move")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                } else {
                    // Select more images button when no photos are selected
                    Button(action: {
                        // Refresh the photo grid to show all photos again
                        photoManager.loadAssets()
                    }) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text("Select More Images")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .sheet(isPresented: $showFolderPicker) {
            FolderPickerView(
                driveManager: driveManager,
                selectedFolder: $selectedFolder,
                onConfirm: { folder in
                    selectedFolder = folder
                    showFolderPicker = false
                    startMove(to: folder)
                }
            )
        }
        .alert("Move Complete", isPresented: $showSuccess) {
            Button("OK") {
                moveResults.removeAll()
                photoManager.clearSelection()
                selectedFolder = nil
            }
        } message: {
            let successCount = moveResults.filter { $0.success }.count
            let totalCount = moveResults.count
            
            if successCount == totalCount {
                Text("\(totalCount) photos deleted and moved to Drive!")
            } else {
                Text("\(successCount) of \(totalCount) photos moved successfully. No photos were deleted.")
            }
        }
    }
    
    private func startMove(to folder: GoogleDriveFolder) {
        isMoving = true
        moveResults.removeAll()
        
        Task {
            let selectedAssets = photoManager.getSelectedAssets()
            var allSuccessful = true
            
            // Upload each file to the selected folder
            for asset in selectedAssets {
                guard let data = await photoManager.getAssetData(for: asset) else {
                    let result = UploadResult(success: false, fileName: photoManager.getAssetFileName(for: asset), error: NSError(domain: "NoData", code: 0), fileId: nil)
                    await MainActor.run {
                        moveResults.append(result)
                        allSuccessful = false
                    }
                    continue
                }
                
                let fileName = photoManager.getAssetFileName(for: asset)
                let uploadResult = await driveManager.uploadFileToFolder(data: data, fileName: fileName, folderId: folder.id)
                
                await MainActor.run {
                    moveResults.append(uploadResult)
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
                isMoving = false
                showSuccess = true
            }
        }
    }
}

struct FolderPickerView: View {
    @ObservedObject var driveManager: GoogleDriveManager
    @Binding var selectedFolder: GoogleDriveFolder?
    let onConfirm: (GoogleDriveFolder) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Text("Select Destination Folder")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Choose where to move your photos")
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
                        Button(action: { selectedFolder = folder }) {
                            HStack {
                                Image(systemName: folder.id == "root" ? "house" : "folder")
                                    .foregroundColor(.blue)
                                Text(folder.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                
                                if selectedFolder?.id == folder.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Divider()
                
                // Confirm button
                if let folder = selectedFolder {
                    Button(action: { onConfirm(folder) }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Confirm Move to \(folder.name)")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .padding()
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
        .onAppear {
            // Ensure folders are loaded when the view appears
            if driveManager.folders.isEmpty {
                Task {
                    await driveManager.loadFolders()
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
                    selectedFolder = folder
                }
            }
        }
        
        newFolderName = ""
    }
}

#Preview {
    ContentView()
}
