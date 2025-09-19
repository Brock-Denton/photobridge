//
//  GoogleAPIConfig.swift
//  PhotoBridge
//
//  Created by Brock Denton on 9/19/25.
//

import Foundation

struct GoogleAPIConfig {
    static let clientId = "74309569492-ebossfoerkapvf1ikhajn6pclaf1qlvl.apps.googleusercontent.com"
    
    static let scopes = [
        "https://www.googleapis.com/auth/drive.file",
        "https://www.googleapis.com/auth/drive.metadata.readonly"
    ]
    
    // Google Drive API endpoints
    static let driveAPIBase = "https://www.googleapis.com/drive/v3"
    static let uploadAPIBase = "https://www.googleapis.com/upload/drive/v3"
}
