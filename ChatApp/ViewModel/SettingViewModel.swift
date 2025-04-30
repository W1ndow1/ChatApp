//
//  SettingViewModel.swift
//  ChatApp
//
//  Created by window1 on 2/6/25.
//

import Foundation
import Combine

class SettingViewModel: ObservableObject {
    @Published var isUserCurrentlyLoggedOut = false
    @Published var currentUser: ChatUser?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        fetchCurrentUser()
    }
    

    func fetchCurrentUser() {
        guard let uid = AuthManager.shared.id else { return }
        DatabaseManager.shared.collectionUsers(userId: uid)
            .sink(receiveCompletion: { completion in
                if case .failure(let failure) = completion {
                    print("Error fetching user:\(failure)")
                    return
                }
            }, receiveValue: { [weak self] user in
                self?.currentUser = user
            })
            .store(in: &cancellables)
        
    }
}
