//
//  ChatLogViewModel.swift
//  ChatApp
//
//  Created by window1 on 2/15/25.
//

import Foundation
import FirebaseCore
import Combine

class ChatLogViewModel: ObservableObject {
    @Published var chatText = ""
    @Published var chatMessages: [ChatMessages] = []
    
    let userData: Set<ChatUser>?
    
    private var cancellables = Set<AnyCancellable>()
    
    init(userData: Set<ChatUser>?) {
        self.userData = userData
        fetchMessages()
    }
    
    //TODO: chatMessageData와 chatRoomData외부 메서드에서 사용가능하게 따로 분리
    func createSendingData() {
        guard let fromId = AuthManager.shared.id else { return }
        guard let selectedUsers = userData?.map({$0.uid}) else { return }
        
        var participants = selectedUsers
        participants.insert(fromId, at: 0)
        
        let chatRoomId = "\(participants.joined(separator: "_"))"
        let chatName = participants.count > 1 ? userData?.map({$0.displayName}).joined(separator: ",") : ""
        let messageId = UUID().uuidString
        
        let chatMessageData = ChatMessages(
            messageId: messageId,
            senderId: fromId,
            text: chatText,
            timeStamp: Timestamp(date: Date()),
            readBy: []
        )
    
        let chatRoomData = ChatRooms(
            chatRoomId: chatRoomId,
            participants: participants,
            isGroup: (participants.count > 2),
            chatName: chatName ?? "",
            lastMessage: chatText,
            lastMessageTimeStamp: chatMessageData.timeStamp
        )
    }
    
    func sendMessage() {
        guard let fromId = AuthManager.shared.id else { return }
        guard let selectedUsers = userData?.map({$0.uid}) else { return }
        
        var participants = selectedUsers
        participants.insert(fromId, at: 0)
        
        let chatRoomId = "\(participants.joined(separator: "_"))"
        let chatName = participants.count > 1 ? userData?.map({$0.displayName}).joined(separator: ",") : ""
        let messageId = UUID().uuidString
        
        let chatMessageData = ChatMessages(
            messageId: messageId,
            senderId: fromId,
            text: chatText,
            timeStamp: Timestamp(date: Date()),
            readBy: []
        )
    
        let chatRoomData = ChatRooms(
            chatRoomId: chatRoomId,
            participants: participants,
            isGroup: (participants.count > 2),
            chatName: chatName ?? "",
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
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Send Message Error : \(error)")
                }
            }, receiveValue: { _ in
                DispatchQueue.main.async {
                    self.chatText = ""
                    self.fetchMessages()
                }
            })
            .store(in: &cancellables)
    }
    
    func fetchMessages() {
        guard let fromId = AuthManager.shared.id else { return }
        guard let selectedUsers = userData?.map({$0.uid}) else { return }
        
        var participants = selectedUsers
        participants.insert(fromId, at: 0)
        let chatRoomId = "\(participants.joined(separator: "_"))"
        
        DatabaseManager.shared.collectionChatMessages(chatRoomId: chatRoomId)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error get message: \(error)")
                }
            }, receiveValue: { chatMessages in
                self.chatMessages = chatMessages
            })
            .store(in: &cancellables)
    }
}
