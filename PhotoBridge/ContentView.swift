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
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        Text("PhotoBridge")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        if driveManager.isAuthenticated {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Connected")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                
                                Button("Sign Out") {
                                    driveManager.signOut()
                                }
                                .font(.caption)
                            }
                        } else {
                            Button("Sign In to Google Drive") {
                                Task {
                                    await driveManager.authenticate()
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                Divider()
                
                // Main content
                if photoManager.authorizationStatus == .authorized || photoManager.authorizationStatus == .limited {
                    PhotoGridView(photoManager: photoManager)
                } else {
                    Spacer()
                }
                
                Divider()
                
                // Upload controls
                UploadProgressView(driveManager: driveManager, photoManager: photoManager)
                    .padding()
                    .background(Color(.systemBackground))
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

#Preview {
    ContentView()
}
