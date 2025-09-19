//
//  PhotoGridView.swift
//  PhotoBridge
//
//  Created by Brock Denton on 9/19/25.
//

import SwiftUI
import Photos

struct PhotoGridView: View {
    @ObservedObject var photoManager: PhotoLibraryManager
    let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    
    var body: some View {
        Group {
            if photoManager.authorizationStatus == .notDetermined {
                AuthorizationView(photoManager: photoManager)
            } else if photoManager.authorizationStatus == .denied {
                DeniedAccessView()
            } else if photoManager.isLoading {
                ProgressView("Loading photos...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(photoManager.assets, id: \.localIdentifier) { asset in
                            PhotoThumbnailView(
                                asset: asset,
                                isSelected: photoManager.isSelected(asset),
                                onTap: {
                                    photoManager.toggleSelection(for: asset)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }
}

struct PhotoThumbnailView: View {
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
                        Image(systemName: "play.fill")
                            .foregroundColor(.white)
                            .font(.caption)
                            .padding(4)
                            .background(Color.black.opacity(0.6), in: Circle())
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

struct AuthorizationView: View {
    @ObservedObject var photoManager: PhotoLibraryManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Photo Access Required")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("PhotoBridge needs access to your photo library to help you move photos to Google Drive.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Grant Access") {
                Task {
                    await photoManager.requestAuthorization()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct DeniedAccessView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Photo Access Denied")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Please go to Settings > Privacy & Security > Photos and enable access for PhotoBridge.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Open Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
