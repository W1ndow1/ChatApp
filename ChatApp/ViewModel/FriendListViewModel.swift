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
    @Published var existChatRooms = [ChatRoom]()

    
    var currentUserId: String {
        AuthManager.shared.id ?? ""
    }
    
    var favoritesUsersCount: Int {
        users.filter { isFavorite($0) }.count
    }
    
    var otherUsersCount: Int {
        users.filter {
            $0.uid != currentUserId && !isFavorite($0)
        }.count
    }
    
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
                    self.fetchFavorites()
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
                DispatchQueue.main.async {
                    self.favoriteUserIds = favoriteIds
                }
            })
            .store(in: &cancellables)
    }
    
    func toggleFavorite(for user: ChatUser) {
        let updateFavorites = favoriteUserIds.contains(user.uid)
        ? favoriteUserIds.subtracting([user.uid])
        : favoriteUserIds.union([user.uid])
        DatabaseManager.shared.updateFavoriteIds(userId: currentUserId, favoriteIds: updateFavorites)
            .sink(receiveCompletion: { completion in
                if case .failure(let failure) = completion {
                    print("Firebase Error: \(failure)")
                    return
                }
                if case .finished = completion {
                    print("success favorite")
                    return
                }
            }, receiveValue: { result in
                self.fetchFavorites()
                
            })
            .store(in: &cancellables)
    }
    
    func isFavorite(_ user: ChatUser) -> Bool {
        return favoriteUserIds.contains(user.uid)
    }
    
    func collectionChatRooms(_ participants: [String]) async {
        let docRef = DatabaseManager.shared.db.collection("rooms")
            .whereField("participants", arrayContainsAny: participants)
            .whereField("chatRoomType", isNotEqualTo: ChatRoomType.group.rawValue)
        do {
            let snapshot = try await docRef.getDocuments()
            await MainActor.run {
                self.existChatRooms = snapshot.documents
                    .compactMap({try? $0.data(as: ChatRoom.self)})
                    .filter { room in
                        let roomParticipants = Set(room.participants)
                        let targetPartocipants = Set(participants)
                        return roomParticipants == targetPartocipants
                    }
            }
        } catch {
            print("Firebase Error: \(error.localizedDescription)")
        }
    }
}
