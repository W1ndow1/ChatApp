//
//  ChatLogViewModel.swift
//  ChatApp
//
//  Created by window1 on 2/15/25.
//

import Foundation
import FirebaseFirestore
import Combine

class ChatLogViewModel: ObservableObject {
    @Published var chatText = ""
    @Published var chatMessages = [ChatMessages]()
    @Published var chatRoom: ChatRooms?
    @Published var fromMessageListView: Bool
    @Published var usersInfo: [String : ChatUser] = [:]

    let userData: Set<ChatUser>?
    
    private var cancellables = Set<AnyCancellable>()
    private var listener: ListenerRegistration?
    
    //새 채팅방 생성시
    init(userData: Set<ChatUser>?, fromMessageListView: Bool = false) {
        self.userData = userData
        self.fromMessageListView = fromMessageListView
    }
    
    //채팅방 목록으로 들어온 경우
    init(chatRoom room: ChatRooms, fromMessageListView: Bool = true) {
        self.userData = .init()
        self.chatRoom = room
        self.fromMessageListView = fromMessageListView
        fetchUserInfo(userIds: room.participants)
    }
    
    func convertToTimeStamp(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a hh:mm"
        return formatter.string(from: date)
    }
    
    private func processChatMessages(_ messages: [ChatMessages]) -> [ChatMessages] {
        var processedMessages = messages
        let calendar = Calendar.current
        
        for i in 0..<processedMessages.count {
            let currentTimestamp = processedMessages[i].timeStamp.dateValue()
            let isFirstMessage = (i == 0)
            
            //이전 메시지 비교
            let perviousTimestamp = isFirstMessage ? nil : processedMessages[i - 1].timeStamp.dateValue()
            
            //같은 날짜 확인
            if isFirstMessage || perviousTimestamp != nil && !calendar.isDate(currentTimestamp, inSameDayAs: perviousTimestamp!) {
                processedMessages[i].isFirstInDayGroup = true
            } else {
                processedMessages[i].isFirstInDayGroup = false
            }
            //같은 시간 확인
            if isFirstMessage || perviousTimestamp != nil && convertToTimeStamp(date: currentTimestamp) != convertToTimeStamp(date: perviousTimestamp!) {
                processedMessages[i].isFirstInTimeGroup = true
            } else {
                processedMessages[i].isFirstInTimeGroup = false
            }
        }
        return processedMessages
    }
    

    
    func sendMessage() {
        guard let fromId = AuthManager.shared.id else { return }
        guard let selectedUsersId = userData?.map({$0.uid}) else { return }
        guard let chatName = userData?.map({$0.displayName}).joined(separator: ",") else { return }
        
        var participants = selectedUsersId
        participants.append(fromId)
        guard let receiverId = participants.count == 2 ? participants.first : "" else { return }
        
        let chatRoomId = participants.sorted(by: { $0 < $1 }).joined(separator: "_")
        let chatMessageData = ChatMessages(
            messageId: UUID().uuidString,
            senderId: fromId,
            receiverId: receiverId,
            text: chatText,
            timeStamp: Timestamp(date: Date()),
            readBy: []
        )
        
        let chatRoomData = ChatRooms(
            chatRoomId: chatRoomId,
            participants: participants.sorted(by: { $0 < $1 }),
            isGroup: (participants.count > 2),
            chatName: chatName,
            lastMessage: chatText,
            lastMessageTimeStamp: chatMessageData.timeStamp
        )
        
        DatabaseManager.shared.checkChatRoomExists(chatRoomId: chatRoomId)
            .flatMap({ exists -> AnyPublisher<Void, Error> in
                if !exists {
                    return DatabaseManager.shared.storeChatRoomData(chatRoomData: chatRoomData)
                } else {
                    return Just(())
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
            })
            .flatMap({ _ in
                DatabaseManager.shared.storeChatMessageData(chatRoomData: chatRoomData, chatMessageData: chatMessageData)
            })
            .flatMap({ _ in
                DatabaseManager.shared.updateChatRoom(chatRoomId: chatRoomId, chatMessageData: chatMessageData)
            })
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Send Message Error : \(error)")
                }
            }, receiveValue: { _ in
                DispatchQueue.main.async {
                    self.chatText = ""
                }
            })
            .store(in: &cancellables)
    }
    
    func sendMessageByRoomId() {
        guard let chatRoomId = chatRoom?.chatRoomId else { return }
        guard let senderId = AuthManager.shared.id else { return }
        let chatMessageData = ChatMessages(messageId: UUID().uuidString,
                                           senderId: senderId,
                                           text: chatText,
                                           timeStamp: Timestamp(date: Date()),
                                           readBy: [])
        DatabaseManager.shared.storeChatMessageData(chatRoomId: chatRoomId, chatMessageData: chatMessageData)
            .flatMap( { _ in
                DatabaseManager.shared.updateChatRoom(chatRoomId: chatRoomId, chatMessageData: chatMessageData)
            })
            .sink(receiveCompletion: { completion in
                if case .failure(let failure) = completion {
                    print("Error send message: \(failure)")
                }
            }, receiveValue: { _ in
                DispatchQueue.main.async {
                    self.chatText = ""
                }
            })
            .store(in: &cancellables)
        
    }
    
    func fetchUserInfo() {
        guard let userIds = userData?.map({$0.uid}) else { return }
        DatabaseManager.shared.collectionUsers(userIds: userIds)
            .sink(receiveCompletion: { completion in
                if case .failure(let failure) = completion {
                    print("🔥Firestore Error: \(failure.localizedDescription)")
                }
            }, receiveValue: { chatUsers in
                self.usersInfo = Dictionary(uniqueKeysWithValues: chatUsers.map{ ($0.uid, $0) })
            })
            .store(in: &cancellables)
    }

    func fetchUserInfo(userIds: [String]) {
        DatabaseManager.shared.collectionUsers(userIds: userIds)
            .sink(receiveCompletion: { completion in
                if case .failure(let failure) = completion {
                    print("🔥Firestore Error: \(failure.localizedDescription)")
                }
            }, receiveValue: { chatUsers in
                self.usersInfo = Dictionary(uniqueKeysWithValues: chatUsers.map{ ($0.uid, $0) })
            })
            .store(in: &cancellables)
    }
    
    func fetchMessages() {
        guard let fromId = AuthManager.shared.id else { return }
        guard let selectedUsers = userData?.map({$0.uid}) else { return }
        let toId = selectedUsers.isEmpty ? fromId : selectedUsers[0]
        
        DatabaseManager.shared.collectionChatMessages(uid1: fromId, uid2: toId)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error get message: \(error)")
                }
            }, receiveValue: { chatMessages in
                self.chatMessages = chatMessages
            })
            .store(in: &cancellables)
    }
    
    func fetchMessagesBySelectedUser() {
        guard let fromId = AuthManager.shared.id else { return }
        var selectedUserId = (userData?.map({$0.uid}))
        selectedUserId?.append(fromId)
        guard let chatRoomId = selectedUserId?.sorted(by: {$0 < $1}).joined(separator: "_") else { return }
        DatabaseManager.shared.collectionChatRooms(chatRoomId: chatRoomId)
            .sink(receiveCompletion: { completion in
                if case .failure(let failure) = completion {
                    print("Error to \(failure)")
                }
                
            }, receiveValue: { messages in
                self.chatMessages = messages
            })
            .store(in: &cancellables)
        
    }
    
    
    //TODO: - 문서 합치지 말고 1개만 조회 하는방식으로 변경하기
    func fetchMessagesListener() {
        listener?.remove()
        guard let fromId = AuthManager.shared.id else { return }
        guard let selectedUsers = userData?.map({$0.uid}) else { return }
        
        let toId = selectedUsers.isEmpty ? fromId : selectedUsers[0]
        DatabaseManager.shared.db.collection("rooms")
            .whereField("participants", arrayContains: fromId)
            .getDocuments { querySnapshot, error in
                if let error = error {
                    print("🔥Firestore Error: \(error.localizedDescription)")
                    return
                }
                let chatRooms = querySnapshot?.documents.filter({ doc in
                    let participants = doc["participants"] as? [String] ?? []
                    return Set(participants) == Set([fromId, toId])
                })
                
                chatRooms?.forEach { chatRoom in
                    self.listener = DatabaseManager.shared.db.collection("rooms")
                        .document(chatRoom.documentID)
                        .collection("messages")
                        .order(by: "timeStamp", descending: false)
                        .addSnapshotListener { snapshot, error in
                            if let error = error {
                                print("🔥Firestore Error: \(error.localizedDescription)")
                                return
                            }
                            snapshot?.documentChanges.forEach { change in
                                switch change.type {
                                case .added:
                                    if let data = try? change.document.data(as: ChatMessages.self) {
                                        self.chatMessages.append(data)
                                        self.chatMessages.sort(by: { $0.timeStamp.dateValue() < $1.timeStamp.dateValue() })
                                    }
                                case .modified:
                                    break;
                                case .removed:
                                    let removeChatMessageId = change.document.documentID
                                    self.chatMessages.removeAll { $0.messageId == removeChatMessageId
                                    }
                                }
                            }
                        }
                }
            }
    }
    
    func fetchMessagesByRoomId() {
        listener?.remove()
        guard let chatRoomId = chatRoom?.chatRoomId else { return }
        DatabaseManager.shared.db.collection("rooms").document(chatRoomId)
            .collection("messages")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("🔥Firestore Error:\(error.localizedDescription)")
                    return
                }
                snapshot?.documentChanges.forEach { change in
                    switch change.type {
                    case .added :
                        if let data = try? change.document.data(as: ChatMessages.self) {
                            self.addMessage(data)
                        }
                    case .modified:
                        break;
                    case .removed:
                        let removeChatMessageId = change.document.documentID
                        self.chatMessages.removeAll(where: { $0.messageId == removeChatMessageId})
                        break;
                    }
                }
            }
    }
    
    func addMessage(_ newMessage: ChatMessages) {
        let calendar = Calendar.current
        var message = newMessage
        let currentTimestamp = message.timeStamp.dateValue()
        
        if chatMessages.isEmpty {
            message.isFirstInDayGroup = true
            message.isFirstInTimeGroup = true
        } else {
            let lastMessage = chatMessages.last!
            let lastTimestamp = lastMessage.timeStamp.dateValue()
            
            // 날짜 그룹
            message.isFirstInDayGroup = !calendar.isDate(currentTimestamp, inSameDayAs: lastTimestamp)
            
            // 시간 그룹
            message.isFirstInTimeGroup = convertToTimeStamp(date: currentTimestamp) != convertToTimeStamp(date: lastTimestamp)
        }
        chatMessages.append(message)
        chatMessages.sort(by: {$0.timeStamp.dateValue() < $1.timeStamp.dateValue()})
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
