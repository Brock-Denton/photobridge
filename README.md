# PhotoBridge

PhotoBridge is an iOS app that helps you move selected photos and videos from your iPhone Photos library to a Google Drive folder, then safely deletes the originals only after successful upload verification.

## Features

- **Fast Photo Grid**: Browse your photo and video library in a responsive grid layout
- **Multi-Select**: Select multiple photos and videos with visual feedback
- **Google Drive Integration**: Choose your destination folder in Google Drive
- **Safe Upload Process**: Uploads files and verifies success before deletion
- **Progress Tracking**: Real-time upload progress with detailed status
- **Smart Deletion**: Only deletes originals if ALL uploads succeed
- **Folder Memory**: Remembers your last used Google Drive folder
- **Error Handling**: Clear success/failure messages with detailed feedback

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Setup Instructions

### 1. Google Drive API Setup

To enable Google Drive integration, you'll need to:

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the Google Drive API
4. Create OAuth 2.0 credentials
5. Update the `GoogleDriveManager.swift` file with your credentials:

```swift
private let clientId = "YOUR_ACTUAL_CLIENT_ID"
private let clientSecret = "YOUR_ACTUAL_CLIENT_SECRET"
```

### 2. App Permissions

The app requires the following permissions (already configured in `PhotoBridge.entitlements`):

- Photos library access (read/write)
- Network access for Google Drive API
- File system access for temporary file handling

### 3. Build and Run

1. Open `PhotoBridge.xcodeproj` in Xcode
2. Select your target device or simulator
3. Build and run the project (⌘+R)

## App Architecture

### Core Components

- **PhotoLibraryManager**: Handles photo library access, selection, and deletion
- **GoogleDriveManager**: Manages Google Drive authentication and file uploads
- **PhotoGridView**: Displays photos in a grid with multi-select functionality
- **GoogleDriveFolderSelector**: Allows users to choose destination folders
- **UploadProgressView**: Shows upload progress and handles the upload workflow

### Key Features Implementation

#### Safe Upload Process
The app implements a two-phase upload process:
1. **Upload Phase**: Uploads all selected files to Google Drive
2. **Verification Phase**: Verifies each upload was successful
3. **Deletion Phase**: Only deletes originals if ALL uploads and verifications succeed

#### Progress Tracking
- Real-time upload progress for each file
- Visual progress indicators
- Detailed status messages
- Error reporting for failed uploads

#### State Management
- Uses `@StateObject` and `@ObservedObject` for reactive UI updates
- Maintains selection state across UI updates
- Persists user preferences using `UserDefaults`

## Usage

1. **Grant Permissions**: Allow photo library access when prompted
2. **Connect to Google Drive**: Tap "Connect to Google Drive" and authenticate
3. **Select Folder**: Choose your destination folder in Google Drive
4. **Select Photos**: Tap photos/videos to select them (blue checkmark indicates selection)
5. **Upload**: Tap "Upload & Delete" to start the process
6. **Monitor Progress**: Watch the upload progress and verification
7. **Review Results**: Check the final success/failure message

## Safety Features

- **No Partial Deletions**: If any upload fails, NO files are deleted
- **Verification Required**: Each upload is verified before considering it successful
- **Clear Feedback**: Detailed success/failure messages
- **Selection Persistence**: Your selection is maintained during the upload process

## Development Notes

### Current Implementation Status

The app includes a complete UI and workflow implementation. The Google Drive integration currently uses simulated authentication and uploads for demonstration purposes. To make it production-ready:

1. Implement real Google Drive OAuth2 authentication
2. Replace simulated uploads with actual Google Drive API calls
3. Add proper error handling for network failures
4. Implement retry logic for failed uploads
5. Add support for large file uploads with resumable uploads

### Testing

The app includes comprehensive error simulation:
- 5% chance of upload failures
- 2% chance of verification failures
- Network delay simulation for realistic testing

## License

This project is created for educational and demonstration purposes.
