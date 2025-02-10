//
//  SettingViewModel.swift
//  ChatApp
//
//  Created by window1 on 2/6/25.
//

import Foundation

class SettingViewModel: ObservableObject {
    @Published var isUserCurrentlyLoggedOut = false
    
    init() {
        DispatchQueue.main.async {
           self.isUserCurrentlyLoggedOut = AuthManager.shared.id == nil
        }
    }
    
    func handleSignOut() {
        isUserCurrentlyLoggedOut.toggle()
        AuthManager.shared.logoutUser()
    }
}
