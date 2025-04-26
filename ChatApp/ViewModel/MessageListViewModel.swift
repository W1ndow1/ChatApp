//
//  MessageListViewModel.swift
//  ChatApp
//
//  Created by window1 on 2/5/25.
//

import Foundation
import Combine
import FirebaseFirestore
import UserNotifications

class MessageListViewModel: ObservableObject {
    @Published var currentUser: ChatUser?
    @Published var chatRooms = [ChatRoom]()
    @Published var usersIdInfo = [String: ChatUser]()
    @Published var favoriteChatRooms = Set<String>()
    
    private var cancellables = Set<AnyCancellable>()
    private var listener: ListenerRegistration?
    private var isPause = false
    
    init() {
        guard let uid = AuthManager.shared.id else { return }
        fetchCurrentUser(uid: uid)
 
        /*
        migrationAllRoomMessageToAddType()
        renameField(completion: { result in
            switch result {
            case .success():
                print("필드 이름 변경 성공")
            case .failure(let error):
                print("Error: \(error)")
            }
        })
         */
    }
    

    func fetchCurrentUser(uid: String) {
        DatabaseManager.shared.collectionUsers(userId: uid)
            .sink(receiveCompletion: { [weak self] completion in
                switch completion {
                case .failure(let error):
                    print("Error fetchCurrent:\(error)")
                case .finished:
                    self?.fetchAllUsersInfo()
                }
            }, receiveValue: { result in
                self.currentUser = result
            })
            .store(in: &cancellables)
    }
    
    func fetchAllUsersInfo() {
        DatabaseManager.shared.collectionAllUsers()
            .sink(receiveCompletion: { completion in
                if case .failure(let failure) = completion {
                    print("🔥Firestore Error: \(failure.localizedDescription)")
                }
                if case .finished = completion {
                    self.fetchChatRooms()
                }
            }, receiveValue: { chatUsers in
                self.usersIdInfo = Dictionary(uniqueKeysWithValues: chatUsers.map{ ($0.uid, $0) })
            })
            .store(in: &cancellables)
    }
    
    
    func fetchChatRooms() {
        guard let uid = AuthManager.shared.id else { return }
        let query = DatabaseManager.shared.db.collection("rooms")
            .whereField("participants", arrayContains: uid)
            .order(by: "lastMessageTimeStamp", descending: true)
        query.getDocuments { snapshot, error in
            if let error = error {
                print("Firebase Error :\(error)")
                return
            }
            guard let snapshot = snapshot?.documents else { return }
            let chatRooms = snapshot.compactMap({ try? $0.data(as: ChatRoom.self)})
            self.editChatRoomsInfo(chatRooms: chatRooms)
            self.fetchChatRoomsStartListner()
        }
    }
    
    func editChatRoomsInfo(chatRooms: [ChatRoom]) {
        for chatRoom in chatRooms {
            let opponentId = chatRoom.participants.first(where: {$0 != AuthManager.shared.id}) ?? chatRoom.participants[0]
            let otherParticipants = chatRoom.participants.filter({$0 != AuthManager.shared.id})
            let groupChatName = otherParticipants.compactMap({usersIdInfo[$0]?.displayName}).joined(separator: ",")
            let newChatRoom = ChatRoom(chatRoomType: chatRoom.chatRoomType,
                                       chatRoomId: chatRoom.chatRoomId,
                                       chatRoomMakerId: chatRoom.chatRoomMakerId,
                                       participants: chatRoom.participants,
                                       participantsJoinDates: chatRoom.participantsJoinDates,
                                       isCustomName: chatRoom.isCustomName,
                                       chatName: chatRoom.chatRoomType == .group
                                       ? chatRoom.isCustomName ? chatRoom.chatName : groupChatName
                                       : (usersIdInfo[opponentId]?.displayName ?? ""),
                                       lastMessage: chatRoom.lastMessage,
                                       lastMessageTimeStamp: chatRoom.lastMessageTimeStamp,
                                       lastMessageSenderId: chatRoom.lastMessageSenderId
            )
            self.chatRooms.append(newChatRoom)
            self.fetchFavoriteRooms(uid: AuthManager.shared.id ?? "")
        }
    }
    
    func editChatRoomInfo(chatRoom: ChatRoom) -> ChatRoom {
        let opponentId = chatRoom.participants.first(where: {$0 != AuthManager.shared.id}) ?? chatRoom.participants[0]
        let otherParticipants = chatRoom.participants.filter({$0 != AuthManager.shared.id})
        let groupChatName = otherParticipants.compactMap({usersIdInfo[$0]?.displayName}).joined(separator: ",")
        let newChatRoom = ChatRoom(chatRoomType: chatRoom.chatRoomType,
                                   chatRoomId: chatRoom.chatRoomId,
                                   chatRoomMakerId: chatRoom.chatRoomMakerId,
                                   participants: chatRoom.participants,
                                   participantsJoinDates: chatRoom.participantsJoinDates,
                                   isCustomName: chatRoom.isCustomName,
                                   chatName: chatRoom.chatRoomType == .group
                                   ? chatRoom.isCustomName ? chatRoom.chatName : groupChatName
                                   : (usersIdInfo[opponentId]?.displayName ?? ""),
                                   lastMessage: chatRoom.lastMessage,
                                   lastMessageTimeStamp: chatRoom.lastMessageTimeStamp,
                                   lastMessageSenderId: chatRoom.lastMessageSenderId)
        return newChatRoom
    }
    
    func fetchChatRoomsStartListner() {
        guard let uid = AuthManager.shared.id else { return }
        let query = DatabaseManager.shared.db.collection("rooms")
            .whereField("participants", arrayContains: uid)
            .order(by: "lastMessageTimeStamp", descending: true)
        query.addSnapshotListener { querySnapshot, errer in
            if let error = errer {
                print("🔥 Firestore Error: \(error.localizedDescription)")
                return
            }
            querySnapshot?.documentChanges.forEach { change in
                switch change.type {
                case .added:
                    if let chatRoom = try? change.document.data(as:ChatRoom.self),
                       !self.chatRooms.contains(where: {$0.chatRoomId == chatRoom.chatRoomId}) {
                        self.chatRooms.append(self.editChatRoomInfo(chatRoom: chatRoom))
                        self.showLocalNotification(chatRoom: chatRoom)
                    }
                case .modified:
                    if let updatedChatRoom = try? change.document.data(as: ChatRoom.self),
                       let index = self.chatRooms.firstIndex(where: { $0.chatRoomId == updatedChatRoom.chatRoomId }) {
                        
                        let previousChatRoom = self.chatRooms[index] //기존 데이터 
                        
                        if previousChatRoom.lastMessage != updatedChatRoom.lastMessage {
                            self.chatRooms[index] = self.editChatRoomInfo(chatRoom: updatedChatRoom)
                            self.showLocalNotification(chatRoom: updatedChatRoom)
                        }
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
    

    func stopListening() {
        listener?.remove()
        listener = nil
        isPause = false
    }
    
    func showLocalNotification(chatRoom: ChatRoom) {
        let msg = ChatMessage(messageId: "",
                              type: .text,
                              senderId: chatRoom.lastMessageSenderId,
                              text: chatRoom.lastMessage,
                              timeStamp: chatRoom.lastMessageTimeStamp,
                              readBy:[])
        guard currentUser?.uid != msg.senderId else { return }
        let content = UNMutableNotificationContent()
        content.title = usersIdInfo[msg.senderId]?.displayName ?? "새로운 메시지"
        content.body = msg.text.count > 30 ? String(msg.text.prefix(20)) : msg.text
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error local Notification:\(error)")
                } else{
                    print("알림요청 성공 - 앱 상태: \(UIApplication.shared.applicationState.rawValue)")
                }
            }
        }
    }
    
    func fetchFavoriteRooms(uid currentId: String) {
        DatabaseManager.shared.collectionFavoritesChatRooms(for: currentId)
            .sink(receiveCompletion: { completion in
                if case .failure(let failure) = completion {
                    print("Firebase Error:\(failure)")
                    return
                }
                if case .finished = completion {
                    return
                }
            }, receiveValue: { favoriteChatRooms in
                DispatchQueue.main.async {
                    self.favoriteChatRooms = favoriteChatRooms
                }
            })
            .store(in: &cancellables)
    }
    
    func toggleFavorite(roomId: String) {
        guard let currentId = AuthManager.shared.id else { return }
        let updateFavorites = favoriteChatRooms.contains(roomId)
        ? favoriteChatRooms.subtracting([roomId])
        : favoriteChatRooms.union([roomId])
        DatabaseManager.shared.updateFavoriteChatRooms(userId: currentId, chatRoomIds: updateFavorites)
            .sink(receiveCompletion: { completion in
                if case .failure(let failure) = completion {
                    print("Firebase Error:\(failure)")
                    return
                }
            }, receiveValue: { [self] result in
                print("Success Favorite Room : \(result)")
                // 변경시 chatRoom 다시 정렬
                fetchFavoriteRooms(uid: currentId)
                
            })
            .store(in: &cancellables)
    }
    
    func isFavorite(_ chatRoom: ChatRoom) -> Bool {
        return favoriteChatRooms.contains(chatRoom.chatRoomId)
    }
    
    func leaveChatRoom(_ chatRoom: ChatRoom) {
        guard let uid = AuthManager.shared.id else { return }
        DatabaseManager.shared.deleteChatRoomParticipant(userId: uid, chatRoomIds: chatRoom.chatRoomId)
            .flatMap({ _ in
                DatabaseManager.shared.deleteChatRoomParticipantJoinDates(userId: uid, chatRoomIds: chatRoom.chatRoomId)
            })
            .sink(receiveCompletion: { complete in
                if case .failure(let failure) = complete {
                    print("Firebase Error:\(failure)")
                }
                if case .finished = complete {
                    self.sendResultMessage(chatRoom: chatRoom)
                }
            }, receiveValue: { value in
                print("Success leave ChatRoom : \(chatRoom.chatName), \(value)")

            })
            .store(in: &cancellables)
    }
    
    func sendResultMessage(chatRoom: ChatRoom) {
        guard let userInfo = currentUser else { return }
        let leaveText = "\(userInfo.displayName)님이 채팅방에서 나갔습니다."
        let resultMessage = ChatMessage(messageId: UUID().uuidString,
                                        type: .leave,
                                        senderId: "leave",
                                        text: leaveText,
                                        timeStamp: Timestamp(date: Date()),
                                        readBy: [])
        DatabaseManager.shared.storeChatMessageData(chatRoomId: chatRoom.chatRoomId , chatMessageData: resultMessage)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print("Error send message: \(error)")
                case .finished:
                     break
                }
            }, receiveValue: { _ in
                
            })
            .store(in: &cancellables)
    }
    
    func updateAllChatRoomsWithChatRoomType(completion: @escaping (Result<Void, Error>) -> Void) {
        let db = DatabaseManager.shared.db
        let roomsCollection = db.collection("rooms")
        
        roomsCollection.getDocuments { snapshot, error in
            if let error = error {
                print("Firestore 조회 실패: \(error)")
                completion(.failure(error))
                return
            }
            
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                print("문서가 없습니다.")
                completion(.success(()))
                return
            }
            
            let batch = db.batch()
            for document in documents {
                let currentData = document.data()
                // chatRoomType 필드가 없는 경우에만 업데이트
                if currentData["chatRoomType"] == nil {
                    let docRef = document.reference
                    batch.updateData(["chatRoomType": ""], forDocument: docRef)
                }
            }
            
            batch.commit { error in
                if let error = error {
                    print("배치 업데이트 실패: \(error)")
                    completion(.failure(error))
                } else {
                    print("배치 업데이트 성공")
                    completion(.success(()))
                }
            }
        }
    }
    
    func renameField(completion: @escaping (Result<Void, Error>) -> Void) {
        let db = DatabaseManager.shared.db
        let roomsCollection = db.collection("rooms")
        
        roomsCollection.getDocuments { snapshot, error in
            if let error = error {
                print("Firebase Error: \(error)")
                completion(.failure(error))
                return
            }
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                print("변환할 문서가 없습니다.")
                completion(.success(()))
                return
            }
            let batch = db.batch()
            for document in documents {
                let docRef = roomsCollection.document(document.documentID)
                if let isGroupValue = document.data()["isGroup"] as? Bool {
                    batch.updateData(["isCustomName" : isGroupValue], forDocument: docRef)
                    batch.updateData(["isGroup" : FieldValue.delete()], forDocument: docRef)
                }
            }
            batch.commit { error in
                if let error = error {
                    print("배치 업데이트 실패: \(error)")
                    completion(.failure(error))
                } else {
                    print("배치 업데이트 성공")
                    completion(.success(()))
                }
            }
        }
    }
    
    func migrationAllRoomMessageToAddType() {
        let db = DatabaseManager.shared.db
        let roomRef = db.collection("rooms")
        
        roomRef.getDocuments { snapshot, error in
            if let error = error {
                print("Firebase Error: \(error)")
                return
            }
            guard let rooms = snapshot?.documents, !rooms.isEmpty else {
                print("변환할 문서가 없습니다.")
                return
            }
            for room in rooms {
                let roomId = room.documentID
                let messageRef = roomRef.document(roomId).collection("messages")
                messageRef.getDocuments{ messagesSnapshot, error in
                    if let error = error {
                        print("Firebase Error: \(error)")
                        return
                    }
                    guard let messages = messagesSnapshot?.documents, !messages.isEmpty else {
                        print("변환할 문서가 없습니다.")
                        return
                    }
                    for message in messages {
                        let data = message.data()
                        if data["type"] != nil {
                            continue
                        }
                        
                        let senderId = data["senderId"] as? String ?? ""
                        var messageType = "text"
                        
                        if senderId == "leave" {
                            messageType = "leave"
                        } else if senderId == "join" {
                            messageType = "join"
                        }
                        
                        messageRef.document(message.documentID).updateData(["type": messageType]) { error in
                            if let error = error {
                                print("메시지 업데이트 실패: \(error)")
                            } else {
                                print("메시지\(message.documentID ) 타입 업데이트 성공")
                            }
                        }
                    }
                }
            }
        }
    }
}


