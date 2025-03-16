//
//  DatabaseManager.swift
//  ChatApp
//
//  Created by window1 on 1/25/25.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreCombineSwift
import FirebaseFunctions
import Combine


class DatabaseManager: NSObject {
    
    enum DatabaseError: Error {
        case updateFiled(String)
    }
    
    static let shared = DatabaseManager()
    
    let db = Firestore.firestore()
    let usersPath: String = "users"
    let chatRoomPath: String = "rooms"
    let chatMesseagesPath: String = "messages"
    let favoritesPath: String = "favorites"
    
    var lastDocument: DocumentSnapshot?
    private var listener: ListenerRegistration?
    private var chatMessagesSubject = PassthroughSubject<[ChatMessage], Error>()
    
    //MARK: - 저장
    func storeUserInformation(userData: [String: Any], uid: String) -> Future<Bool, Error>{
        return Future<Bool, Error> { promise in
            self.db.collection(self.usersPath).document(uid).setData(userData) { error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(true))
                }
            }
        }
    }
    
    func storeUserInformation(userData: ChatUser, uid: String) -> Future<Bool, Error> {
        return Future<Bool, Error> { promise in
            do {
                try self.db.collection(self.usersPath).document(uid).setData(from: userData) { error in
                    if let error = error {
                        promise(.failure(error))
                    } else {
                        promise(.success(true))
                    }
                }
            } catch {
                promise(.failure(error))
            }
        }
    }
    
    func storeChatRoomData(chatRoomData: ChatRoom) -> AnyPublisher<Void, Error> {
        let chatRoomRef = db.collection(chatRoomPath).document(chatRoomData.chatRoomId)
        return Future { promise in
            do {
                try chatRoomRef.setData(from: chatRoomData) { error in
                    if let error = error {
                        promise(.failure(error))
                    } else {
                        promise(.success(()))
                    }
                }
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func storeChatMessageData(chatRoomData: ChatRoom, chatMessageData: ChatMessage) -> Future<Bool, Error> {
        return Future<Bool, Error> { promise in
            do {
                try self.db.collection(self.chatRoomPath).document(chatRoomData.chatRoomId)
                    .collection(self.chatMesseagesPath).document(chatMessageData.messageId)
                    .setData(from: chatMessageData) { error in
                        if let error = error {
                            promise(.failure(error))
                        } else {
                            promise(.success(true))
                        }
                    }
            } catch {
                promise(.failure(error))
            }
        }
    }
    
    func storeChatMessageData(chatRoomId: String, chatMessageData: ChatMessage) -> Future<Bool, Error> {
        return Future<Bool, Error> { promise in
            do {
                try self.db.collection(self.chatRoomPath).document(chatRoomId)
                    .collection(self.chatMesseagesPath).document(chatMessageData.messageId)
                    .setData(from: chatMessageData) { error in
                        if let error = error {
                            promise(.failure(error))
                        } else {
                            promise(.success(true))
                        }
                    }
            } catch {
                promise(.failure(error))
            }
        }
    }
    
    //MARK: - 수정
    func updateChatRoom(chatRoomId: String, chatMessageData: ChatMessage) -> AnyPublisher<Bool, Error> {
        let chatRoomRef = db.collection(chatRoomPath).document(chatRoomId)
        return Future { promise in
            let batch = self.db.batch()
            batch.updateData([
                "lastMessage" : chatMessageData.text,
                "lastMessageTimeStamp" : chatMessageData.timeStamp,
                "lastMessageSenderId" : chatMessageData.senderId
                
            ], forDocument: chatRoomRef)
            batch.commit() { error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(true))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func updateUserDisplayName(userId: String, displayName: String) -> AnyPublisher<Bool, Error> {
        let usersRef = db.collection(self.usersPath).document(userId)
        return Future { promise in
            usersRef.updateData(["displayName" : displayName]) {
                error in
                if let error = error {
                    promise(.failure(DatabaseError.updateFiled(error.localizedDescription)))
                } else {
                    promise(.success(true))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func updateUserProfileImageURL(userId: String, imageURL: String) -> AnyPublisher<Bool, Error> {
        let userRef = db.collection(self.usersPath).document(userId)
        return Future { promise in
            userRef.updateData(["profileImageURL" : imageURL], completion: { error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(true))
                }
            })
        }
        .eraseToAnyPublisher()
    }
    
    func updateFavoriteIds(userId: String, favoriteIds: Set<String>) -> AnyPublisher<Bool, Error> {
        let favoriteRef = db.collection(self.favoritesPath).document(userId)
        return Future { promise in
            favoriteRef.setData(["favoriteIds": Array(favoriteIds)]) { error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(true))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func updateFavoriteChatRooms(userId: String, chatRoomIds: Set<String>) -> AnyPublisher<Bool, Error> {
        let favoriteRef = db.collection(self.favoritesPath).document(userId)
        return Future { promise in
            favoriteRef.setData(["favoriteChatRooms": Array(chatRoomIds)]) { error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(true))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    //MARK: - 불러오기
    func collectionFavoritesUsers(for userId: String) -> AnyPublisher<Set<String>, Error> {
        return Future { promise in
            self.db.collection("favorites").document(userId)
                .getDocument() { snapshot, error in
                    if let error = error {
                        promise(.failure(error))
                        return
                    }
                    let favoriteIds = snapshot?.data()?["favoriteIds"] as? Set<String> ?? []
                    promise(.success(favoriteIds))
                }
        }
        .eraseToAnyPublisher()
    }
    
    func collectionFavoritesChatRooms(for userId: String) -> AnyPublisher<Set<String>, Error> {
        return Future { promise in
            self.db.collection("favorites").document(userId)
                .getDocument() { snapshot, error in
                    if let error = error {
                        promise(.failure(error))
                        return
                    }
                    if let favoriteIds = snapshot?.data()?["favoriteChatRooms"] as? [String] {
                        promise(.success(Set(favoriteIds)))
                    } else {
                        promise(.success(Set()))
                    }
                }
        }
        .eraseToAnyPublisher()
    }
    
    
    func collectionUsersExceptionOfUser(exceptionId id: String) -> AnyPublisher<[ChatUser], Error> {
        return Future { promise in
            self.db.collection(self.usersPath)
                .whereField("uid", isNotEqualTo: id)
                .getDocuments { snapshot, error in
                    if let error = error {
                        promise(.failure(error))
                        return
                    }
                    let document = snapshot?.documents ?? []
                    do {
                        let userList = try document.map({ try $0.data(as: ChatUser.self) })
                        promise(.success(userList))
                    } catch {
                        promise(.failure(error))
                    }
                }
        }
        .eraseToAnyPublisher()
    }
    
    func collectionUsers(userId id: String) -> AnyPublisher<ChatUser, Error> {
        Future<ChatUser, Error> { promise in
            self.db.collection(self.usersPath).document(id).getDocument { snapshot, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                do {
                    if let user = try snapshot?.data(as: ChatUser.self) {
                        promise(.success(user))
                    } else {
                        promise(.failure(NSError()))
                    }
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func collectionUsers(userIds ids: [String]) -> AnyPublisher<[ChatUser], Error> {
        return Future { promise in
            self.db.collection(self.usersPath).whereField("uid", in: ids)
                .getDocuments { snapshot, error in
                    if let error = error {
                        promise(.failure(error))
                        return
                    }
                    let document = snapshot?.documents ?? []
                    do {
                        let userList = try document.map({try $0.data(as: ChatUser.self)})
                        promise(.success(userList))
                    } catch {
                        promise(.failure(error))
                    }
                }
        }
        .eraseToAnyPublisher()
    }
    
    func collectionAllUsers() -> AnyPublisher<[ChatUser], Error> {
        return Future { promise in
            self.db.collection(self.usersPath).getDocuments() { snapshot, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                let documents = snapshot?.documents ?? []
                    do {
                        let users = try documents.map({ try $0.data(as: ChatUser.self)})
                        promise(.success(users))
                    } catch {
                        promise(.failure(error))
                    }
                }
            }
        .eraseToAnyPublisher()
        }
    
    func collectionChatRooms(chatRoomId roomId: String) -> AnyPublisher<[ChatMessage], Error> {
        let chatMessagesRef = self.db.collection(self.chatRoomPath).document(roomId)
            .collection(self.chatMesseagesPath)
            .order(by: "timeStamp", descending: false)
        chatMessagesRef.addSnapshotListener { snapshot, error in
            if let error = error {
                print("Firebase Error:\(error)")
                return
            }
            var messages = [ChatMessage]()
            snapshot?.documentChanges.forEach { change in
                switch change.type {
                case .added:
                    if let message = try? change.document.data(as: ChatMessage.self) {
                        messages.append(message)
                    }
                case .modified:
                    break;
                case .removed:
                    break;
                }
            }
            self.chatMessagesSubject.send(messages)
        }
        return chatMessagesSubject.eraseToAnyPublisher()
    }
    
    func collectionChatRooms(uid id: String) -> AnyPublisher<[ChatRoom], Error> {
        return Future { promise in
            self.db.collection(self.chatRoomPath)
                .whereField("participants", arrayContains: id)
                .order(by: "lastMessageTimeStamp", descending: true)
                .getDocuments { snapshot, error in
                    if let error {
                        promise(.failure(error))
                        return
                    }
                    guard let documents = snapshot?.documents else {
                        promise(.failure(NSError(domain: "Firestore", code: 0, userInfo: [NSLocalizedDescriptionKey: "No chat rooms found"])))
                        return
                    }
                    do {
                        let chatRooms = try documents.map({ try $0.data(as: ChatRoom.self) })
                        promise(.success(chatRooms))
                    } catch {
                        promise(.failure(error))
                    }
                }
        }
        .eraseToAnyPublisher()
    }

    func collectionChatMessages(chatRoomId: String) -> AnyPublisher<[ChatMessage], Error> {
        return Future { promise in
            self.db.collection(self.chatRoomPath).document(chatRoomId)
                .collection(self.chatMesseagesPath)
                .order(by: "timeStamp", descending: true)
                .limit(to: 20)
                .getDocuments { snapshot, error in
                    if let error {
                        promise(.failure(error))
                        return
                    }
                    self.lastDocument = snapshot?.documents.last
                    let documents = snapshot?.documents ?? []
                    do {
                        let initialMessages = try documents.compactMap({try $0.data(as: ChatMessage.self)})
                        promise(.success(initialMessages.reversed()))
                    } catch {
                        promise(.failure(error))
                    }
                }
        }
        .eraseToAnyPublisher()
    }
    
    func startCollectionChatMessagesRealTimeListener(chatRoomId: String) -> AnyPublisher<ChatMessage, Error> {
        return Future { [weak self] promise in
            self?.listener = DatabaseManager.shared.db.collection("rooms").document(chatRoomId)
                .collection("messages")
                .order(by: "timeStamp", descending: true)
                .limit(to: 20)
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        promise(.failure(error))
                    }
                    guard let snapshot = snapshot else { return }
                    snapshot.documentChanges.forEach { change in
                        switch change.type {
                        case .added:
                            if let msg = try? change.document.data(as: ChatMessage.self) {
                                promise(.success(msg))
                            }
                        case .modified, .removed:
                            break
                        }
                    }
                }
        }
        .eraseToAnyPublisher()
    }

    //MARK: - 확인하기
    
    func checkChatRoomExists(chatRoomId: String) -> AnyPublisher<Bool, Error> {
        let chatRoomRef = db.collection(chatRoomPath).document(chatRoomId)
        return Future { promise in
            chatRoomRef.getDocument() { document, error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(document?.exists ?? false))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    
}
