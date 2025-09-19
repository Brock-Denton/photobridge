//
//  GoogleAPIConfig.swift
//  PhotoBridge
//
//  Created by Brock Denton on 9/19/25.
//

import Foundation

struct GoogleAPIConfig {
    // Replace these with your actual Google Cloud Console credentials
    static let clientId = "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com"
    static let clientSecret = "YOUR_GOOGLE_CLIENT_SECRET"
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
    
    static var authURLString: String {
        var components = URLComponents(string: authURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopeString),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        return components.url!.absoluteString
    }
}
