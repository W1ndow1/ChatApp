import Foundation
import FirebaseCore

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
    
    //UI에서만 사용
    var isNew: Bool = false
    
    
    enum CodingKeys: String, CodingKey {
        case chatRoomType
        case chatRoomId
        case chatRoomMakerId
        case participants
        case participantsJoinDates
        case isCustomName
        case chatName
        case lastMessage
        case lastMessageTimeStamp
        case lastMessageSenderId
    }
}

enum ChatRoomType: String, Codable, CaseIterable {
    case direct = "direct"
    case group = "group"
    case selfChat = "selfChat"
    case advertisement = "advertisement"
}
