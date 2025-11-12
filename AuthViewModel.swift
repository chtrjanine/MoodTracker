// File: AuthViewModel.swift

import Foundation
import FirebaseAuth
import Combine
import GoogleSignIn
import GoogleSignInSwift
import UIKit

class AuthViewModel: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User? 
    
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.userSession = Auth.auth().currentUser
        
        // Listen for authentication state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.userSession = user
            // fetch user profile from Firestore
        }
    }
    
    func signIn(withEmail email: String, password: String) async -> Bool {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.userSession = result.user
            print("DEBUG: User signed in: \(result.user.uid)")
            return true
        } catch {
            print("DEBUG: Failed to sign in with error: \(error.localizedDescription)")
            return false
        }
    }
    
    func signUp(withEmail email: String, password: String) async -> Bool {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            self.userSession = result.user
            print("DEBUG: User signed up and logged in: \(result.user.uid)")
            // Here you could create a new user document in Firestore
            return true
        } catch {
            print("DEBUG: Failed to sign up with error: \(error.localizedDescription)")
            return false
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.userSession = nil
            print("DEBUG: User signed out.")
        } catch {
            print("DEBUG: Failed to sign out with error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Google Sign In

    func signInWithGoogle() async -> Bool {
        guard let topViewController = await getTopViewController() else {
            print("DEBUG: Could not find top view controller.")
            return false
        }
            
        do {
            let gidSignInResult = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: topViewController
            )

            guard let idToken = gidSignInResult.user.idToken?.tokenString else {
                print("DEBUG: Google ID Token not found.")
                return false
            }
            let accessToken = gidSignInResult.user.accessToken.tokenString
                
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )
                
            let result = try await Auth.auth().signIn(with: credential)
            self.userSession = result.user
            print("DEBUG: User signed in with Google: \(result.user.uid)")
            return true

        } catch {
            print("DEBUG: Failed to sign in with Google: \(error.localizedDescription)")
            return false
        }
    }
        
    @MainActor
    private func getTopViewController() async -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .first?
            .windows
            .filter { $0.isKeyWindow }
            .first
                
        guard var topViewController = keyWindow?.rootViewController else {
            return nil
        }
            
        while let presentedViewController = topViewController.presentedViewController {
            topViewController = presentedViewController
        }
            
        return topViewController
    }
}

