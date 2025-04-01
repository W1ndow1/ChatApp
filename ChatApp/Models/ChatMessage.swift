//
//  MessageModel.swift
//  ChatApp
//
//  Created by window1 on 2/15/25.
//

import Foundation
import FirebaseCore

struct ChatMessage: Identifiable, Codable {
    var id: String { messageId }
    var messageId: String
    var senderId: String
    var receiverId: String = ""
    var text: String = ""
    var timeStamp: Timestamp
    var readBy: [String]
    var isFirstInDayGroup: Bool?
    var isFirstInTimeGroup: Bool?
    var isFromSameSender: Bool?
}

struct ChatRoom: Identifiable, Codable, Hashable {
    var id: String { chatRoomId }
    var chatRoomType: ChatRoomType?
    var chatRoomId: String = ""
    var chatRoomMakerId: String = ""
    var participants: [String] = []
    var participantsJoinDates: [String : Timestamp]?
    var isCustomName: Bool = false
    var chatName: String = ""
    var lastMessage: String = ""
    var lastMessageTimeStamp: Timestamp = Timestamp()
    var lastMessageSenderId: String = ""
}

enum ChatRoomType: String, Codable, CaseIterable {
    case direct = "direct"
    case group = "group"
    case selfChat = "selfChat"
    case advertisement = "advertisement"
}
