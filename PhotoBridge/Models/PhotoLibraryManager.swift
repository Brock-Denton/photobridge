//
//  PhotoLibraryManager.swift
//  PhotoBridge
//
//  Created by Brock Denton on 9/19/25.
//

import Photos
import SwiftUI
import Foundation

@MainActor
class PhotoLibraryManager: ObservableObject {
    @Published var assets: [PHAsset] = []
    @Published var selectedAssets: Set<String> = []
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var isLoading = false
    
    private let imageManager = PHCachingImageManager()
    
    init() {
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if authorizationStatus == .authorized || authorizationStatus == .limited {
            loadAssetsWithLoading()
        }
    }
    
    func requestAuthorization() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            authorizationStatus = status
            if status == .authorized || status == .limited {
                loadAssetsWithLoading()
            }
        }
    }
    
    func refreshPhotoAccess() async {
        // This will trigger the iOS photo selection interface if user has limited access
        // Similar to "Edit Selected Photos" in Settings
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            authorizationStatus = status
            if status == .authorized || status == .limited {
                loadAssetsWithLoading()
            }
        }
    }
    
    func loadAssets() {
        // Don't show loading spinner for refresh - just update silently
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.includeHiddenAssets = false
        
        let allAssets = PHAsset.fetchAssets(with: fetchOptions)
        
        var assetArray: [PHAsset] = []
        allAssets.enumerateObjects { asset, _, _ in
            assetArray.append(asset)
        }
        
        DispatchQueue.main.async {
            self.assets = assetArray
            print("📸 Loaded \(assetArray.count) photos")
        }
    }
    
    func loadAssetsWithLoading() {
        isLoading = true
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.includeHiddenAssets = false
        
        let allAssets = PHAsset.fetchAssets(with: fetchOptions)
        
        var assetArray: [PHAsset] = []
        allAssets.enumerateObjects { asset, _, _ in
            assetArray.append(asset)
        }
        
        DispatchQueue.main.async {
            self.assets = assetArray
            self.isLoading = false
            print("📸 Loaded \(assetArray.count) photos")
        }
    }
    
    func toggleSelection(for asset: PHAsset) {
        let identifier = asset.localIdentifier
        if selectedAssets.contains(identifier) {
            selectedAssets.remove(identifier)
            print("📸 Deselected photo: \(identifier)")
        } else {
            selectedAssets.insert(identifier)
            print("📸 Selected photo: \(identifier)")
        }
        print("📸 Total selected: \(selectedAssets.count)")
    }
    
    func isSelected(_ asset: PHAsset) -> Bool {
        return selectedAssets.contains(asset.localIdentifier)
    }
    
    func clearSelection() {
        selectedAssets.removeAll()
    }
    
    func getSelectedAssets() -> [PHAsset] {
        return assets.filter { selectedAssets.contains($0.localIdentifier) }
    }
    
    func deleteSelectedAssets() async throws {
        let assetsToDelete = getSelectedAssets()
        guard !assetsToDelete.isEmpty else { return }
        
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
        }
        
        // Remove from local arrays
        selectedAssets.removeAll()
        
        // Refresh the asset list on main thread
        await MainActor.run {
            loadAssets()
        }
    }
    
    func getAssetData(for asset: PHAsset) async -> Data? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            if asset.mediaType == .image {
                imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                    continuation.resume(returning: data)
                }
            } else if asset.mediaType == .video {
                let videoOptions = PHVideoRequestOptions()
                videoOptions.isNetworkAccessAllowed = true
                videoOptions.deliveryMode = .highQualityFormat
                
                imageManager.requestAVAsset(forVideo: asset, options: videoOptions) { avAsset, _, _ in
                    guard let urlAsset = avAsset as? AVURLAsset else {
                        print("❌ Failed to get URL asset for video")
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    do {
                        let data = try Data(contentsOf: urlAsset.url)
                        print("✅ Successfully extracted video data: \(data.count) bytes")
                        continuation.resume(returning: data)
                    } catch {
                        print("❌ Failed to read video data: \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                    }
                }
            } else {
                continuation.resume(returning: nil)
            }
        }
    }
    
    func getAssetFileName(for asset: PHAsset) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = formatter.string(from: asset.creationDate ?? Date())
        
        if asset.mediaType == .image {
            return "IMG_\(dateString).jpg"
        } else if asset.mediaType == .video {
            // Try to determine the actual video format
            if let resource = PHAssetResource.assetResources(for: asset).first {
                let originalFilename = resource.originalFilename
                if originalFilename.lowercased().hasSuffix(".mp4") {
                    return "VID_\(dateString).mp4"
                } else if originalFilename.lowercased().hasSuffix(".mov") {
                    return "VID_\(dateString).mov"
                } else if originalFilename.lowercased().hasSuffix(".m4v") {
                    return "VID_\(dateString).m4v"
                }
            }
            // Default to .mov if we can't determine the format
            return "VID_\(dateString).mov"
        }
        
        return "FILE_\(dateString)"
    }
}

import AVFoundation
