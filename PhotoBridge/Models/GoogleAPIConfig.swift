//
//  GoogleAPIConfig.swift
//  PhotoBridge
//
//  Created by Brock Denton on 9/19/25.
//

import Foundation

struct GoogleAPIConfig {
    // Replace these with your actual Google Cloud Console credentials
    static let clientId = "74309569492-ebossfoerkapvf1ikhajn6pclaf1qlvl.apps.googleusercontent.com"
    static let redirectURI = "com.photobridge.app://oauth"
    
    // Google Drive API endpoints
    static let authURL = "https://accounts.google.com/o/oauth2/v2/auth"
    static let tokenURL = "https://oauth2.googleapis.com/token"
    static let driveAPIBase = "https://www.googleapis.com/drive/v3"
    static let uploadAPIBase = "https://www.googleapis.com/upload/drive/v3"
    
    // Scopes required for the app
    static let scopes = [
        "https://www.googleapis.com/auth/drive.file",
        "https://www.googleapis.com/auth/drive.metadata.readonly"
    ]
    
    static var scopeString: String {
        return scopes.joined(separator: " ")
    }
}
