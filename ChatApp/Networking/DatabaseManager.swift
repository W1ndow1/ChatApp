//
//  DatabaseManager.swift
//  ChatApp
//
//  Created by window1 on 1/25/25.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreCombineSwift
import Combine


class DatabaseManager: NSObject {
    
    static let shared = DatabaseManager()
    
    let db = Firestore.firestore()
    let usersPath: String = "users"
    let chatRoomPath: String = "rooms"
    let chatMesseagesPath: String = "messages"
    
    
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
    
    func storeChatRoomData(chatRoomData: ChatRooms) -> AnyPublisher<Void, Error> {
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

    
    func storeChatMessageData(chatRoomData: ChatRooms, chatMessageData: ChatMessages) -> Future<Bool, Error> {
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
    
    
    
    func collectionUsers(uid id: String) -> AnyPublisher<ChatUser, Error> {
        Future<ChatUser, Error>{ promise in
            self.db.collection(self.usersPath).document(id).getDocument { snapshot, error in
                if let error = error {
                    promise(.failure(error))
                    print("Error fetching chats:\(error)")
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
    
    func collectionAllUsers() -> AnyPublisher<[ChatUser], Error> {
        return Future { promise in
            self.db.collection(self.usersPath).getDocuments() { snapshot, error in
                if let error = error {
                    promise(.failure(error))
                    return
                } else if let documents = snapshot?.documents {
                    do {
                        let users = try documents.map({ try $0.data(as: ChatUser.self)})
                        promise(.success(users))
                    } catch {
                        promise(.failure(error))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    
    func collectionChatRooms(uid id: String) -> AnyPublisher<[ChatRooms], Error> {
        return Future { promise in
            self.db.collection(self.chatRoomPath).whereField("participants", arrayContains: id)
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
                        let chatRooms = try documents.map({ try $0.data(as: ChatRooms.self) })
                        promise(.success(chatRooms))
                    } catch {
                        promise(.failure(error))
                    }
                }
        }
        .eraseToAnyPublisher()
    }
    
    
    func collectionChatMessages(chatRoomId roomId: String) -> AnyPublisher<[ChatMessages], Error> {
        return Future { promise in
            self.db.collection(self.chatRoomPath).document(roomId).collection(self.chatMesseagesPath)
                .order(by: "timeStamp", descending: false)
                .getDocuments { snapshot, error in
                    if let error {
                        promise(.failure(error))
                        return
                    }
                    guard let documents = snapshot?.documents else {
                        promise(.failure(NSError(domain: "Firestore", code: 0, userInfo: [NSLocalizedDescriptionKey: "No message found"])))
                        return
                    }
                    do {
                        let chatMessages = try documents.map({ try $0.data(as: ChatMessages.self) })
                        promise(.success(chatMessages))
                    } catch {
                        promise(.failure(error))
                    }
                }
        }
        .eraseToAnyPublisher()
    }
    
    
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
