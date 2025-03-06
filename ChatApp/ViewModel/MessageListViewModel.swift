//
//  MessageListViewModel.swift
//  ChatApp
//
//  Created by window1 on 2/5/25.
//

import Foundation
import Combine
import FirebaseFirestore

class MessageListViewModel: ObservableObject {
    @Published var errorMessage = ""
    @Published var currentUser: ChatUser?
    @Published var profileURL: String?
    @Published var profileImage: UIImage?
    @Published var chatRooms: [ChatRooms] = []
    @Published var chatRoomIdInfo: [String : ChatUser] = [:]
    @Published var userIdInfo: [String: ChatUser] = [:]
    
    private var cancellables = Set<AnyCancellable>()
    private var listener: ListenerRegistration?
    private var isPause = false
    
    init() {
        stopListening()
        guard let uid = AuthManager.shared.id else { return }
        fetchUserInfo()
        fetchCurrentUser(uid: uid)
    }
    
    func fetchCurrentUser(uid: String) {
        DatabaseManager.shared.collectionUsers(userId: uid)
            .sink(receiveCompletion: { [weak self] completion in
                switch completion {
                case .failure(let error):
                    print("Error fetchCurrent:\(error)")
                case .finished:
                    self?.fetchChatRoomsListener()
                }
            }, receiveValue: { result in
                self.currentUser = result
            })
            .store(in: &cancellables)
    }
    
    
    func fetchChatRoomsListener() {
        guard let uid = AuthManager.shared.id else { return }
        if listener == nil {
            listener = DatabaseManager.shared.db.collection("rooms")
                .whereField("participants", arrayContains: uid)
                .order(by: "lastMessageTimeStamp", descending: true)
                .addSnapshotListener { querySnapshot, errer in
                    //if self.isPause { return }
                    if let error = errer {
                        print("🔥 Firestore Error: \(error.localizedDescription)")
                        return
                    }
                    querySnapshot?.documentChanges.forEach { change in
                        switch change.type {
                        case .added:
                            if let data = try? change.document.data(as:ChatRooms.self),
                               !self.chatRooms.contains(where: {$0.chatRoomId == data.chatRoomId}) {
                                self.chatRooms.append(data)
                                self.fetchUsersInfo(for: data)
                            }
                        case .modified:
                            if let updatedChatRoom = try? change.document.data(as: ChatRooms.self),
                               let index = self.chatRooms.firstIndex(where: { $0.chatRoomId == updatedChatRoom.chatRoomId }) {
                                self.chatRooms[index] = updatedChatRoom
                                self.fetchUsersInfo(for: updatedChatRoom)
                            }
                        case .removed:
                            let removedChatRoomId = change.document.documentID
                            self.chatRooms.removeAll { $0.chatRoomId == removedChatRoomId }
                        }
                    }
                    self.chatRooms.sort(by: {
                        $0.lastMessageTimeStamp.dateValue() > $1.lastMessageTimeStamp.dateValue()
                    })
                }
        }
    }
    
    func fetchUserInfo() {
        DatabaseManager.shared.collectionAllUsers()
            .sink(receiveCompletion: { completion in
                if case .failure(let failure) = completion {
                    print("🔥Firestore Error: \(failure.localizedDescription)")
                }
            }, receiveValue: { chatUsers in
                self.userIdInfo = Dictionary(uniqueKeysWithValues: chatUsers.map{ ($0.uid, $0) })
            })
            .store(in: &cancellables)
    }
    
    func fetchUsersInfo(for room: ChatRooms) {
        guard let uid = AuthManager.shared.id else { return }
        guard let opponentId = room.participants.first(where: { $0 != uid }) else {
            chatRoomIdInfo[room.chatRoomId] = currentUser
            return }
        
        DatabaseManager.shared.collectionUsers(userId: opponentId)
            .sink(receiveCompletion: { completion in
                if case .failure(let failure) = completion {
                    print("🔥Firestore Error: \(failure.localizedDescription)")
                }
            }, receiveValue: { result in
                self.chatRoomIdInfo[room.chatRoomId] = result
            })
            .store(in: &cancellables)
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
        isPause = false
    }
}


