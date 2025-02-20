//
//  MessageListViewModel.swift
//  ChatApp
//
//  Created by window1 on 2/5/25.
//

import Foundation
import Combine
import UIKit
import FirebaseFirestore

class MessageListViewModel: ObservableObject {
    @Published var errorMessage = ""
    @Published var currentUser: ChatUser?
    @Published var profileURL: String?
    @Published var profileImage: UIImage?
    @Published var chatRooms: [ChatRooms] = []
    
    private var cancellables = Set<AnyCancellable>()
    private var listener: ListenerRegistration?
    private var listenerIsActive = false
    
    init() {
        fetchCurrentUser()
        fetchChatRoomsListener()
    }
    
    func fetchCurrentUser() {
        guard let uid = AuthManager.shared.id else { return }
        DatabaseManager.shared.collectionUsers(uid: uid)
            .handleEvents(receiveOutput:  { user in
                guard let imageURL = URL(string: user.profileImageURL) else { return }
                Task {
                    await self.fetchImage(url: imageURL)
                }
            })
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let failure) = completion {
                    self?.errorMessage = failure.localizedDescription
                }
            }, receiveValue: { user in
                self.currentUser = user
            })
            .store(in: &cancellables)
    }
    
    private func fetchImage(url: URL) async {
        do {
            let request = URLRequest(url: url)
            let (data, _) = try await URLSession.shared.data(for: request)
            if let uiimage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.profileImage = uiimage
                }
            }
        } catch {
            print("Failed to load Image", error)
        }
    }
    
    func fetchChatRooms() {
        guard let uid = AuthManager.shared.id else { return }
        DatabaseManager.shared.collectionChatRooms(uid: uid)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let failure) = completion {
                    self?.errorMessage = failure.localizedDescription
                }
            }, receiveValue: { chatRooms in
                self.chatRooms = chatRooms
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
                    if let error = errer {
                        print("🔥 Firestore Error: \(error.localizedDescription)")
                        return
                    }
                    querySnapshot?.documentChanges.forEach { change in
                        switch change.type {
                        case .added:
                            if let data = try? change.document.data(as:ChatRooms.self) {
                                self.chatRooms.append(data)
                            }
                            
                        case .modified:
                            if let updatedChatRoom = try? change.document.data(as: ChatRooms.self),
                               let index = self.chatRooms.firstIndex(where: { $0.chatRoomId == updatedChatRoom.chatRoomId }) {
                                self.chatRooms[index] = updatedChatRoom
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

    func getUserImageURL(id: String) {
        DatabaseManager.shared.collectionUsers(uid: id)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let failure) = completion {
                    self?.errorMessage = failure.localizedDescription
                }
            }, receiveValue: { userData in
                self.profileURL = userData.profileImageURL
            })
            .store(in: &cancellables)
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func pauseListener() {
        listenerIsActive = false
    }
    
    func resumeListener() {
        listenerIsActive = true
        //fetchChatRoomsListener()
    }
}


