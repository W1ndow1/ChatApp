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
    var type: ChatMessageType?
    var senderId: String
    var receiverId: String = ""
    var text: String = ""
    var timeStamp: Timestamp
    var readBy: [String]
    var isFirstInDayGroup: Bool?
    var isFirstInTimeGroup: Bool?
    var isFromSameSender: Bool?
}


enum ChatMessageType: String, Codable, CaseIterable {
    case text = "text"
    case image = "image"
    case video = "video"
    case leave = "leave"
    case join = "join"
}
			
