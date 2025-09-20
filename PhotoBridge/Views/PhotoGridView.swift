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
    @State private var selectedAsset: PHAsset?
    @State private var showFullScreen = false
    
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
                                    print("📸 PhotoGridView: Asset tapped - \(asset.localIdentifier)")
                                    photoManager.toggleSelection(for: asset)
                                },
                                onLongPress: {
                                    selectedAsset = asset
                                    showFullScreen = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .onAppear {
                    print("📸 PhotoGridView: Displaying \(photoManager.assets.count) assets")
                }
                .fullScreenCover(isPresented: $showFullScreen) {
                    if let asset = selectedAsset {
                        FullScreenPhotoView(
                            asset: asset,
                            isSelected: photoManager.isSelected(asset),
                            onToggleSelection: {
                                photoManager.toggleSelection(for: asset)
                            },
                            onDismiss: {
                                showFullScreen = false
                                selectedAsset = nil
                            }
                        )
                    }
                }
            }
        }
    }
}

struct PhotoThumbnailView: View {
    let asset: PHAsset
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    
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
        .onLongPressGesture {
            onLongPress()
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

struct FullScreenPhotoView: View {
    let asset: PHAsset
    let isSelected: Bool
    let onToggleSelection: () -> Void
    let onDismiss: () -> Void
    
    @State private var fullImage: UIImage?
    @State private var isLoading = true
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    private let imageManager = PHCachingImageManager()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let image = fullImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 1.0), 5.0)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    if scale < 1.0 {
                                        withAnimation(.spring()) {
                                            scale = 1.0
                                            offset = .zero
                                        }
                                    }
                                },
                            DragGesture()
                                .onChanged { value in
                                    if scale > 1.0 {
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            if scale > 1.0 {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.0
                            }
                        }
                    }
            } else if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
            
            // Top controls
            VStack {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Button(action: onToggleSelection) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundColor(isSelected ? .blue : .white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                Spacer()
            }
            
            // Bottom info
            VStack {
                Spacer()
                
                VStack(spacing: 8) {
                    Text("Double tap to zoom • Pinch to zoom • Drag when zoomed")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                    
                    if isSelected {
                        Text("✓ Selected")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .fontWeight(.semibold)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            loadFullImage()
        }
    }
    
    private func loadFullImage() {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        let targetSize = CGSize(width: 2000, height: 2000)
        
        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                self.fullImage = image
                self.isLoading = false
            }
        }
    }
}
