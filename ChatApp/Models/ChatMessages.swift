//
//  MessageModel.swift
//  ChatApp
//
//  Created by window1 on 2/15/25.
//

import Foundation
import FirebaseCore

struct ChatMessages: Identifiable, Codable {
    var id: String { messageId }
    var messageId: String
    var senderId: String
    var receiverId: String = ""
    var text: String = ""
    var timeStamp: Timestamp
    var readBy: [String]
}

struct ChatRooms: Identifiable, Codable {
    var id: String { chatRoomId }
    var chatRoomId: String
    var participants: [String]
    var isGroup: Bool = false
    var chatName: String = ""
    var lastMessage: String = ""
    var lastMessageTimeStamp: Timestamp
}
