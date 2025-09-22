//
//  ContentView.swift
//  PhotoBridge
//
//  Created by Brock Denton on 9/19/25.
//

import SwiftUI
import Photos

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
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Text("PhotoBridge")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                
                Text("Move your photos from camera roll to Google Drive")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
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
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 1.0, green: 0.6, blue: 0.2), // Warm orange
                    Color(red: 0.9, green: 0.4, blue: 0.1), // Deeper orange
                    Color(red: 0.7, green: 0.2, blue: 0.1), // Dark red-orange
                    Color(red: 0.4, green: 0.1, blue: 0.2), // Deep purple-brown
                    Color(red: 0.1, green: 0.05, blue: 0.1)  // Almost black
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .ignoresSafeArea()
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
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Text("Photo Access Required")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                
                Text("PhotoBridge needs access to your photo library to help you move photos to Google Drive.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
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
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 1.0, green: 0.6, blue: 0.2), // Warm orange
                    Color(red: 0.9, green: 0.4, blue: 0.1), // Deeper orange
                    Color(red: 0.7, green: 0.2, blue: 0.1), // Dark red-orange
                    Color(red: 0.4, green: 0.1, blue: 0.2), // Deep purple-brown
                    Color(red: 0.1, green: 0.05, blue: 0.1)  // Almost black
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .ignoresSafeArea()
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
    @State private var hasUsedSelectMore = false
    @State private var isGridView = true
    
    var selectedCount: Int {
        let count = photoManager.selectedAssets.count
        print("📸 Selected count: \(count)")
        return count
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Photo display
                if photoManager.isLoading {
                    Spacer()
                    ProgressView("Loading photos...")
                    Spacer()
                } else if isGridView {
                    PhotoGridViewWithFullScreen(photoManager: photoManager)
                } else {
                    SinglePhotoView(photoManager: photoManager)
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
                } else if !hasUsedSelectMore {
                    // Select more images button - only show once
                    Button(action: {
                        print("📸 Select More Images button tapped!")
                        hasUsedSelectMore = true
                        
                        // Back to the original simple version that worked
                        photoManager.loadAssets()
                        
                        // Force UI update by clearing and reloading
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            photoManager.loadAssets()
                        }
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
                } else {
                    // After first use, show message that they need to restart app
                    VStack(spacing: 8) {
                        Text("Restart App to select more photos")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Close and reopen PhotoBridge to refresh the photo selection")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            }
            
            // Header - positioned in front of content
            VStack {
                HStack {
                    Button(action: {
                        isGridView.toggle()
                    }) {
                        Image(systemName: isGridView ? "rectangle.grid.2x2" : "photo")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
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
                .background(Color(.systemBackground).opacity(0.95))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                Spacer()
            }
            .zIndex(1)
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

struct SinglePhotoView: View {
    @ObservedObject var photoManager: PhotoLibraryManager
    @State private var currentIndex = 0
    @State private var currentImage: UIImage?
    @State private var isLoading = true
    
    private let imageManager = PHCachingImageManager()
    
    var body: some View {
        VStack(spacing: 0) {
            // Photo display
            ZStack {
                if let image = currentImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(isScreenshot(image) ? 1.25 : 1.0)
                } else if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
                
                // Selection overlay
                if !photoManager.assets.isEmpty {
                    let currentAsset = photoManager.assets[currentIndex]
                    if photoManager.isSelected(currentAsset) {
                        Rectangle()
                            .fill(Color.blue.opacity(0.3))
                            .overlay(
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.largeTitle)
                                    .background(Color.white, in: Circle())
                            )
                    }
                }
            }
            .onTapGesture {
                if !photoManager.assets.isEmpty {
                    let currentAsset = photoManager.assets[currentIndex]
                    photoManager.toggleSelection(for: currentAsset)
                }
            }
            
            // Navigation controls
            HStack {
                Button(action: previousPhoto) {
                    Image(systemName: "chevron.left")
                        .font(.title)
                        .foregroundColor(.blue)
                }
                .disabled(currentIndex == 0)
                
                Spacer()
                
                Text("\(currentIndex + 1) of \(photoManager.assets.count)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: nextPhoto) {
                    Image(systemName: "chevron.right")
                        .font(.title)
                        .foregroundColor(.blue)
                }
                .disabled(currentIndex >= photoManager.assets.count - 1)
            }
                    .padding()
                    .background(Color(.systemBackground))
        }
        .onAppear {
            loadCurrentImage()
        }
        .onChange(of: currentIndex) { _ in
            loadCurrentImage()
        }
    }
    
    private func previousPhoto() {
        if currentIndex > 0 {
            currentIndex -= 1
        }
    }
    
    private func nextPhoto() {
        if currentIndex < photoManager.assets.count - 1 {
            currentIndex += 1
        }
    }
    
    private func loadCurrentImage() {
        guard !photoManager.assets.isEmpty && currentIndex < photoManager.assets.count else { return }
        
        isLoading = true
        let asset = photoManager.assets[currentIndex]
        
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        let targetSize = CGSize(width: 1000, height: 1000)
        
        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                self.currentImage = image
                self.isLoading = false
            }
        }
    }
    
    private func isScreenshot(_ image: UIImage) -> Bool {
        let width = image.size.width
        let height = image.size.height
        let aspectRatio = width / height
        
        // Screenshots typically have aspect ratios close to device screen ratios
        // iPhone screenshots are usually around 0.46-0.56 (portrait) or 1.8-2.2 (landscape)
        // Regular photos are usually more square (0.7-1.4)
        return aspectRatio < 0.6 || aspectRatio > 1.6
    }
}

struct PhotoGridViewWithFullScreen: View {
    @ObservedObject var photoManager: PhotoLibraryManager
    let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 3)
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(photoManager.assets, id: \.localIdentifier) { asset in
                    PhotoThumbnailViewSimple(
                        asset: asset,
                        isSelected: photoManager.isSelected(asset),
                        onTap: {
                            print("📸 PhotoGridView: Asset tapped - \(asset.localIdentifier)")
                            photoManager.toggleSelection(for: asset)
                        }
                    )
                }
            }
            .padding(.horizontal, 1)
            .padding(.bottom, 20) // Add bottom padding to ensure last row is fully visible
        }
        .scrollContentBackground(.hidden)
        .onAppear {
            print("📸 PhotoGridView: Displaying \(photoManager.assets.count) assets")
        }
    }
}

struct PhotoThumbnailViewSimple: View {
    let asset: PHAsset
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var thumbnailImage: UIImage?
    @State private var isLoading = true
    
    private let imageManager = PHCachingImageManager()
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(1, contentMode: .fit)
            
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
            
            // Selection overlay
            if isSelected {
                Rectangle()
                    .fill(Color.blue.opacity(0.3))
                    .overlay(
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                            .background(Color.white, in: Circle())
                    )
            }
            
            // Media type indicator
            VStack {
                HStack {
                    Spacer()
                    if asset.mediaType == .video {
                        VStack(spacing: 2) {
                            Image(systemName: "play.fill")
                                .foregroundColor(.white)
                                .font(.caption2)
                            Text("VIDEO")
                                .foregroundColor(.white)
                                .font(.system(size: 8, weight: .bold))
                        }
                        .padding(6)
                        .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                Spacer()
            }
            .padding(4)
        }
        .onTapGesture {
            onTap()
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        
        let targetSize = CGSize(width: 200, height: 200)
        
        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                self.thumbnailImage = image
                self.isLoading = false
            }
        }
    }
}


#Preview {
    ContentView()
}
