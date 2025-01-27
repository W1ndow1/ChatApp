//
//  ChatAppApp.swift
//  ChatApp
//
//  Created by window1 on 1/11/25.
//

import SwiftUI
import FirebaseCore
import FirebaseStorage
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct ChatAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            LoginView()
                .environmentObject(LoginViewModel())
        }
    }
}
