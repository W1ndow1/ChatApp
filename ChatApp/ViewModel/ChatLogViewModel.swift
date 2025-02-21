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
    @Published var chatRooms = [ChatRooms]()
    @Published var chatRoomId: String?
    
    let userData: Set<ChatUser>?
    
    private var cancellables = Set<AnyCancellable>()
    private var listener: ListenerRegistration?
    
    //새 채팅방 생성시
    init(userData: Set<ChatUser>?) {
        self.userData = userData
        fetchMessagesListener()
    }
    
    //채팅방 목록으로 들어온 경우
    init(chatRoomId roomId: String) {
        self.userData = .init()
        self.chatRoomId = roomId
        fetchMessagesByRoomId()
        
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
            participants: participants.sorted(),
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
        guard let chatRoomId = chatRoomId else { return }
        guard let senderId = AuthManager.shared.id else { return }
        let chatMessageData = ChatMessages(messageId: chatText,
                                           senderId: senderId,
                                           timeStamp: Timestamp(date: Date()),
                                           readBy: [])
        DatabaseManager.shared.db.collection("rooom").document(chatRoomId)
            .collection("messages").addSnapshotListener { snapshot, error in
                if let error = error {
                    print("🔥Firebase Error:\(error)")
                    return
                }
                snapshot?.documentChanges.forEach { change in
                    switch change.type {
                    case .added:
                        if let data = try? change.document.data(as: ChatMessages.self) {
                            self.chatMessages.append(data)
                            self.chatMessages.sort(by: {$0.timeStamp.dateValue() < $1.timeStamp.dateValue()})
                        }
                    case .modified:
                        break;
                    case .removed:
                        let removeChatMessageId = change.document.documentID
                        self.chatMessages.removeAll(where: {$0.messageId == removeChatMessageId})
                        break;
                    }
                }
            }
        
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
        guard let fromID = AuthManager.shared.id else { return }
        guard let chatRoomId = chatRoomId else { return }
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
                            self.chatMessages.append(data)
                            self.chatMessages.sort(by: {$0.timeStamp.dateValue() < $1.timeStamp.dateValue()})
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
    
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
