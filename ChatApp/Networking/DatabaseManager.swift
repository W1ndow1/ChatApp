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
    
    static let shared = DatabaseManager()
    
    let db = Firestore.firestore()
    let usersPath: String = "users"
    let chatRoomPath: String = "rooms"
    let chatMesseagesPath: String = "messages"
    
    private var listener: ListenerRegistration?
    
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
    //MARK: - 수정
    func updateChatRoom(chatRoomId: String, chatMessageData: ChatMessages) -> AnyPublisher<Bool, Error> {
        let chatRoomRef = db.collection(chatRoomPath).document(chatRoomId)
        return Future { promise in
            let batch = self.db.batch()
            batch.updateData([
                "lastMessage" : chatMessageData.text,
                "lastMessageTimeStamp" : chatMessageData.timeStamp
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
    
    
    //MARK: - 조회
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
                        let chatRooms = try documents.map({ try $0.data(as: ChatRooms.self) })
                        promise(.success(chatRooms))
                    } catch {
                        promise(.failure(error))
                    }
                }
        }
        .eraseToAnyPublisher()
    }
    
    //FireFunciton의 경우 추후 수정해야함
    func collectionChatMessagesToFireFunction(userId1: String, userId2: String) -> AnyPublisher<[ChatMessages], Error> {
        let function = Functions.functions()
        return Future { promise in
            function.httpsCallable("filterDocuments").call(["userId1": userId1, "userId2": userId2]) { result, error in
                if let error = error {
                    print("Error fetching chat room: \(error.localizedDescription)")
                    promise(.failure(error))
                    return
                }
                
                guard let data = result?.data as? [[String: Any]] else {
                    promise(.failure(NSError(domain: "Invalid data", code: -1, userInfo: nil)))
                    return
                }
                
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
                    let decodedChatRooms = try JSONDecoder().decode([ChatMessages].self, from: jsonData)
                    promise(.success(decodedChatRooms))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    
    func collectionChatMessages(uid1: String, uid2: String) -> AnyPublisher<[ChatMessages], Error> {
        return Future { promise in
            self.db.collection(self.chatRoomPath)
                .whereField("participants", arrayContains: uid1)
                .getDocuments { querySnapshot, error in
                    if let error = error {
                        print("🔥Firestore Error: \(error.localizedDescription)")
                        promise(.failure(error))
                        return
                    }
                    guard let documents = querySnapshot?.documents else {
                        print("⚠️ No documents found for user \(uid1), \(uid2)")
                        promise(.failure(NSError()))
                        return
                    }
                    
                    let chatRooms = documents.filter { doc in
                        let participants = doc["participants"] as? [String] ?? []
                        return Set(participants) == Set([uid1, uid2])
                    }
                    let dispatchGroup = DispatchGroup()
                    var allMessages = [ChatMessages]()
                    
                    for chatRoom in chatRooms {
                        dispatchGroup.enter()
                        self.db.collection(self.chatRoomPath)
                            .document(chatRoom.documentID)
                            .collection(self.chatMesseagesPath)
                            .order(by: "timeStamp", descending: false)
                            .getDocuments { snapshot, error in
                                if let error {
                                    print("🔥 Firestore Error: \(error.localizedDescription)")
                                    promise(.failure(error))
                                    return
                                }
                                guard let messageDocs = snapshot?.documents else {
                                    print("⚠️ No documents found for user \(uid1), \(uid2)")
                                    promise(.failure(NSError()))
                                    return
                                }
                                let chatMessage = messageDocs.compactMap({ try? $0.data(as: ChatMessages.self)})
                                allMessages.append(contentsOf: chatMessage)
                                dispatchGroup.leave()
                            }
                    }
                    dispatchGroup.notify(queue: .main) {
                        allMessages.sort(by: { $0.timeStamp.dateValue() < $1.timeStamp.dateValue() })
                        promise(.success(allMessages))
                    }
                }
        }
        .eraseToAnyPublisher()
    }
    
    
    func collectionChatMessagesLisener(uid1: String, uid2: String) -> AnyPublisher<[ChatMessages], Error> {
        listener?.remove()
        return Future { promise in
            self.db.collection(self.chatRoomPath)
                .whereField("participants", arrayContains: uid1)
                .getDocuments { querySnapshot, error in
                    if let error = error {
                        print("🔥Firestore Error: \(error.localizedDescription)")
                        promise(.failure(error))
                        return
                    }
                    guard let documents = querySnapshot?.documents else {
                        print("⚠️ No documents found for user \(uid1), \(uid2)")
                        promise(.failure(NSError()))
                        return
                    }
                    let chatRooms = documents.filter { doc in
                        let participants = doc["participants"] as? [String] ?? []
                        return Set(participants) == Set([uid1, uid2])
                    }
                    guard chatRooms.first != nil else {
                        print("⚠️ No 1:1 chat room found for \(uid1) and \(uid2)")
                        return
                    }
                    
                    var allMessages = [ChatMessages]()
                    for chatRoom in chatRooms {
                        self.listener = self.db.collection(self.chatRoomPath)
                            .document(chatRoom.documentID)
                            .collection(self.chatMesseagesPath)
                            .order(by: "timeStamp", descending: false)
                            .addSnapshotListener({ snapshot, error in
                                if let error {
                                    print("🔥 Firestore Error: \(error.localizedDescription)")
                                    promise(.failure(error))
                                    return
                                }
                                guard let messageDocs = snapshot?.documents else {
                                    print("⚠️ No documents found for user \(uid1), \(uid2)")
                                    promise(.failure(NSError()))
                                    return
                                }
                                allMessages = messageDocs.compactMap { try? $0.data(as: ChatMessages.self) }
                                allMessages.append(contentsOf: allMessages)

                            })
                    }
                    promise(.success(allMessages))
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
