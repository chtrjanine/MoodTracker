//  File: MoodTrackerApp.swift

import SwiftUI
import FirebaseCore // Import FirebaseCore

// Add AppDelegate to configure Firebase
class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}

@main
struct MoodTrackerApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // Create an instance of the AuthViewModel and keep it alive for the app's lifecycle
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            // Check if a user session exists
            if authViewModel.userSession != nil {
                // If logged in, show the main content view
                ContentView()
                    .environmentObject(authViewModel) // Pass the view model to all child views
            } else {
                // If not logged in, show the login view
                LoginView()
                    .environmentObject(authViewModel) // Also pass it here for login/signup actions
            }
        }
    }
}
