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
    
    //UI에서만 사용
    var isFirstInDayGroup: Bool = false
    var isFirstInTimeGroup: Bool = false
    var isFromSameSender: Bool = false
    var sendState: MessageSendState = .sent
    
    enum CodingKeys: String, CodingKey {
        case messageId, type, senderId, receiverId, text, timeStamp, readBy
    }
}


enum ChatMessageType: String, Codable, CaseIterable {
    case text = "text"
    case image = "image"
    case video = "video"
    case leave = "leave"
    case join = "join"
}
			
enum MessageSendState: Codable, CaseIterable {
    case sending
    case sent
    case failed
}
