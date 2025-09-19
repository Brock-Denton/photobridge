//
//  GoogleAuthManager.swift
//  PhotoBridge
//
//  Created by Brock Denton on 9/19/25.
//

import Foundation
import SwiftUI
import AuthenticationServices

struct AuthTokenResponse: Codable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
    let token_type: String
}

struct AuthError: Error {
    let message: String
    let code: Int
}

@MainActor
class GoogleAuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var accessToken: String?
    @Published var refreshToken: String?
    
    private let accessTokenKey = "google_drive_access_token"
    private let refreshTokenKey = "google_drive_refresh_token"
    private let tokenExpiryKey = "google_drive_token_expiry"
    
    init() {
        loadStoredTokens()
    }
    
    private func loadStoredTokens() {
        accessToken = UserDefaults.standard.string(forKey: accessTokenKey)
        refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey)
        
        if let expiry = UserDefaults.standard.object(forKey: tokenExpiryKey) as? Date {
            if Date() < expiry && accessToken != nil {
                isAuthenticated = true
            } else {
                // Token expired, try to refresh
                Task {
                    await refreshAccessToken()
                }
            }
        }
    }
    
    func startAuthentication() async throws {
        guard let authURL = URL(string: GoogleAPIConfig.authURLString) else {
            throw AuthError(message: "Invalid auth URL", code: -1)
        }
        
        // For iOS, we'll use ASWebAuthenticationSession
        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "com.photobridge.app"
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                if let error = error {
                    print("Auth error: \(error)")
                    return
                }
                
                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    print("No auth code received")
                    return
                }
                
                await self?.exchangeCodeForToken(code: code)
            }
        }
        
        session.presentationContextProvider = AuthPresentationContextProvider()
        session.start()
    }
    
    private func exchangeCodeForToken(code: String) async {
        guard let tokenURL = URL(string: GoogleAPIConfig.tokenURL) else { return }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "client_id": GoogleAPIConfig.clientId,
            "client_secret": GoogleAPIConfig.clientSecret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": GoogleAPIConfig.redirectURI
        ]
        
        request.httpBody = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(AuthTokenResponse.self, from: data)
            
            accessToken = response.access_token
            refreshToken = response.refresh_token
            isAuthenticated = true
            
            // Store tokens
            UserDefaults.standard.set(response.access_token, forKey: accessTokenKey)
            if let refreshToken = response.refresh_token {
                UserDefaults.standard.set(refreshToken, forKey: refreshTokenKey)
            }
            
            // Store expiry
            let expiry = Date().addingTimeInterval(TimeInterval(response.expires_in))
            UserDefaults.standard.set(expiry, forKey: tokenExpiryKey)
            
        } catch {
            print("Token exchange failed: \(error)")
        }
    }
    
    func refreshAccessToken() async {
        guard let refreshToken = refreshToken else { return }
        
        guard let tokenURL = URL(string: GoogleAPIConfig.tokenURL) else { return }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "client_id": GoogleAPIConfig.clientId,
            "client_secret": GoogleAPIConfig.clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        
        request.httpBody = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(AuthTokenResponse.self, from: data)
            
            accessToken = response.access_token
            isAuthenticated = true
            
            UserDefaults.standard.set(response.access_token, forKey: accessTokenKey)
            
            let expiry = Date().addingTimeInterval(TimeInterval(response.expires_in))
            UserDefaults.standard.set(expiry, forKey: tokenExpiryKey)
            
        } catch {
            print("Token refresh failed: \(error)")
            // If refresh fails, user needs to re-authenticate
            signOut()
        }
    }
    
    func signOut() {
        accessToken = nil
        refreshToken = nil
        isAuthenticated = false
        
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: tokenExpiryKey)
    }
}

class AuthPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
