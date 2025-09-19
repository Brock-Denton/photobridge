//
//  GoogleDriveFolderSelector.swift
//  PhotoBridge
//
//  Created by Brock Denton on 9/19/25.
//

import SwiftUI

struct GoogleDriveFolderSelector: View {
    @ObservedObject var driveManager: GoogleDriveManager
    @State private var showingFolderPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder")
                    .foregroundColor(.blue)
                Text("Google Drive Folder")
                    .font(.headline)
                Spacer()
            }
            
            if driveManager.isAuthenticated {
                Button(action: {
                    showingFolderPicker = true
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(driveManager.selectedFolder?.name ?? "Select a folder")
                                .font(.body)
                                .foregroundColor(driveManager.selectedFolder != nil ? .primary : .secondary)
                            
                            if let folder = driveManager.selectedFolder {
                                Text(folder.path)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Button("Connect to Google Drive") {
                    Task {
                        await driveManager.authenticate()
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showingFolderPicker) {
            FolderPickerView(driveManager: driveManager)
        }
    }
}

struct FolderPickerView: View {
    @ObservedObject var driveManager: GoogleDriveManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Debug: \(driveManager.folders.count) folders")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                
                List(driveManager.folders) { folder in
                Button(action: {
                    driveManager.selectFolder(folder)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(folder.name)
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Text(folder.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if driveManager.selectedFolder?.id == folder.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Select Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
