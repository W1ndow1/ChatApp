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
    @Published var errorMessage = ""
    @Published var currentUser: ChatUser?
    @Published var profileURL: String?
    @Published var profileImage: UIImage?
    @Published var chatRooms: [ChatRoom] = []
    @Published var chatRoomIdInfo: [String : ChatUser] = [:]
    @Published var usersIdInfo: [String: ChatUser] = [:]
    @Published var favoriteChatRooms = Set<String>()
    
    private var cancellables = Set<AnyCancellable>()
    private var listener: ListenerRegistration?
    private var isPause = false
    
    init() {
        guard let uid = AuthManager.shared.id else { return }
        fetchCurrentUser(uid: uid)
    }

    func fetchCurrentUser(uid: String) {
        DatabaseManager.shared.collectionUsers(userId: uid)
            .sink(receiveCompletion: { [weak self] completion in
                switch completion {
                case .failure(let error):
                    print("Error fetchCurrent:\(error)")
                case .finished:
                    self?.fetchAllUsersInfo()
                    //추후 push messages 이용시
                    //self?.fetchChatRoomsListener()
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
                    if let error = errer {
                        print("🔥 Firestore Error: \(error.localizedDescription)")
                        return
                    }
                    querySnapshot?.documentChanges.forEach { change in
                        switch change.type {
                        case .added:
                            if let chatRoom = try? change.document.data(as:ChatRoom.self),
                               !self.chatRooms.contains(where: {$0.chatRoomId == chatRoom.chatRoomId}) {
                                self.chatRooms.append(chatRoom)
                                self.fetchUsersInfo(for: chatRoom)
                                
                            }
                        case .modified:
                            if let updatedChatRoom = try? change.document.data(as: ChatRoom.self),
                               let index = self.chatRooms.firstIndex(where: { $0.chatRoomId == updatedChatRoom.chatRoomId }) {
                                self.chatRooms[index] = updatedChatRoom
                                self.showLocalNotification(chatRoom: updatedChatRoom)
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
            let newChatRoom = ChatRoom(chatRoomId: chatRoom.chatRoomId,
                                       chatRoomMakerId: chatRoom.chatRoomMakerId,
                                       participants: chatRoom.participants,
                                       isGroup: chatRoom.isGroup,
                                       chatName: chatRoom.isGroup ? chatRoom.chatName : (usersIdInfo[opponentId]?.displayName ?? ""),
                                       lastMessage: chatRoom.lastMessage,
                                       lastMessageTimeStamp: chatRoom.lastMessageTimeStamp,
                                       lastMessageSenderId: chatRoom.lastMessageSenderId)
            self.chatRooms.append(newChatRoom)
            self.fetchFavoriteRooms(uid: AuthManager.shared.id ?? "")
        }
    }
    
    func editChatRoomInfo(chatRoom: ChatRoom) -> ChatRoom {
        let opponentId = chatRoom.participants.first(where: {$0 != AuthManager.shared.id}) ?? chatRoom.participants[0]
        let newChatRoom = ChatRoom(chatRoomId: chatRoom.chatRoomId,
                                   chatRoomMakerId: chatRoom.chatRoomMakerId,
                                   participants: chatRoom.participants,
                                   isGroup: chatRoom.isGroup,
                                   chatName: chatRoom.isGroup ? chatRoom.chatName : (usersIdInfo[opponentId]?.displayName ?? ""),
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
                        self.chatRooms[index] = self.editChatRoomInfo(chatRoom: updatedChatRoom)
                        self.showLocalNotification(chatRoom: updatedChatRoom)
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
    
    func fetchUsersInfo(for room: ChatRoom) {
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
    
    func fetchUsersInfo(for rooms: [ChatRoom]) {
        guard let uid = AuthManager.shared.id else { return }
        for room in rooms {
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
    }
    
    
    func stopListening() {
        listener?.remove()
        listener = nil
        isPause = false
    }
    
    func showLocalNotification(chatRoom: ChatRoom) {
        let msg = ChatMessage(messageId: "",
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
        guard let uid = AuthManager.shared.id,
              let userInfo = currentUser else { return }
        let leaveText = "\(userInfo.displayName)님이 채팅방에서 나갔습니다."
        let resultMessage = ChatMessage(messageId: UUID().uuidString,
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
}


