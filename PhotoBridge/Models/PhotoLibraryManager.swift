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
            loadAssets()
        }
    }
    
    func requestAuthorization() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            authorizationStatus = status
            if status == .authorized || status == .limited {
                loadAssets()
            }
        }
    }
    
    func loadAssets() {
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
                imageManager.requestAVAsset(forVideo: asset, options: nil) { avAsset, _, _ in
                    guard let urlAsset = avAsset as? AVURLAsset else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    do {
                        let data = try Data(contentsOf: urlAsset.url)
                        continuation.resume(returning: data)
                    } catch {
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
            return "VID_\(dateString).mov"
        }
        
        return "FILE_\(dateString)"
    }
}

import AVFoundation
