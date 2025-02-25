//
//  ChatAppApp.swift
//  ChatApp
//
//  Created by window1 on 1/11/25.
//

import SwiftUI
import Firebase

@main
struct ChatAppApp: App {
    @StateObject var viewModel = LoginViewModel()
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            HomeTabView()
                .tint(.pink)
                .environmentObject(viewModel)
        }
    }
}
