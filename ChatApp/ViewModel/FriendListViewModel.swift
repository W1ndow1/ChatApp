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
    @Published var favoriteUserIds = Set<String>()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        fetchAllUsers()
        fetchFavorites()
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
    
    private func fetchFavorites() {
        guard let currentId = AuthManager.shared.id else { return }
        DatabaseManager.shared.collectionFavoritesUsers(for: currentId)
            .sink(receiveCompletion: { completion in
                if case .failure(let failure) = completion {
                    print("Firebase Error:\(failure)")
                    return
                }
                if case .finished = completion {
                    return
                }
            }, receiveValue: { favoriteIds in
                self.favoriteUserIds = favoriteIds
            })
            .store(in: &cancellables)
    }
    
    func toggleFavorite(for user: ChatUser) {
        guard let currentId = AuthManager.shared.id else { return }
        if favoriteUserIds.contains(user.uid) {
            favoriteUserIds.remove(user.uid)
        } else {
            favoriteUserIds.insert(user.uid)
        }
        DatabaseManager.shared.updateFavoriteIds(userId: currentId, favoriteIds: favoriteUserIds)
            .sink(receiveCompletion: { completion in
                if case .failure(let failure) = completion {
                    print("Firebase Error: \(failure)")
                    return
                }
                if case .finished = completion {
                    print("success favorite")
                    return
                }
            }, receiveValue: { _ in
                
            })
            .store(in: &cancellables)
    }
    
    func isFavorite(_ user: ChatUser) -> Bool {
        return favoriteUserIds.contains(user.uid)
    }
}
