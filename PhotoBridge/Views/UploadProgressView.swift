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
                
                Button(action: startUpload) {
                    HStack {
                        if isUploading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "icloud.and.arrow.up")
                        }
                        
                        Text(isUploading ? "Uploading..." : "Upload & Delete")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canUpload ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(!canUpload || isUploading)
                
                if isUploading {
                    UploadProgressDetailsView(
                        driveManager: driveManager,
                        photoManager: photoManager
                    )
                }
            }
        }
        .alert("Upload Complete", isPresented: $showResults) {
            Button("OK") {
                uploadResults.removeAll()
            }
        } message: {
            let successCount = uploadResults.filter { $0.success }.count
            let totalCount = uploadResults.count
            
            if successCount == totalCount {
                Text("All \(totalCount) files uploaded successfully and deleted from your device!")
            } else {
                Text("\(successCount) of \(totalCount) files uploaded successfully. No files were deleted.")
            }
        }
    }
    
    private var canUpload: Bool {
        selectedCount > 0 && 
        driveManager.isAuthenticated && 
        driveManager.selectedFolder != nil &&
        !isUploading
    }
    
    private func startUpload() {
        guard canUpload else { return }
        
        isUploading = true
        uploadResults.removeAll()
        
        Task {
            let selectedAssets = photoManager.getSelectedAssets()
            var allSuccessful = true
            
            // Upload each file
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
                let uploadResult = await driveManager.uploadFile(data: data, fileName: fileName)
                
                await MainActor.run {
                    uploadResults.append(uploadResult)
                    if !uploadResult.success {
                        allSuccessful = false
                    }
                }
                
                // Verify upload
                if uploadResult.success, let fileId = uploadResult.fileId {
                    let verified = await driveManager.verifyUpload(fileName: fileName, fileId: fileId)
                    if !verified {
                        await MainActor.run {
                            if let index = uploadResults.firstIndex(where: { $0.fileName == fileName }) {
                                uploadResults[index] = UploadResult(success: false, fileName: fileName, error: NSError(domain: "VerificationFailed", code: 1), fileId: fileId)
                                allSuccessful = false
                            }
                        }
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
