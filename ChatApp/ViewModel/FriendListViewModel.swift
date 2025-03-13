//
//  FriendListViewModel.swift
//  ChatApp
//
//  Created by window1 on 3/12/25.
//

import Foundation
import Combine


class FriendListViewModel: ObservableObject {
    @Published var users = [ChatUser]()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        fetchAllUsers()
    }
    
    private func fetchAllUsers() {
        DatabaseManager.shared.collectionAllUsers()
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print("Error fetching users: \(error.localizedDescription)")
                case .finished:
                    break;
                }
            }, receiveValue: { users in
                self.users = users
            })
            .store(in: &cancellables)
    }
}
