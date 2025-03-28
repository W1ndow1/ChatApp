import Foundation
import FirebaseFirestore
import Combine
import UserNotifications

class ChatLogViewModel: ObservableObject {
    @Published var chatText = ""
    @Published var chatMessages: [ChatMessage] = []
    @Published var chatRoom: ChatRoom?
    @Published var usersInfo: [String : ChatUser]?
    @Published var selectedUser: Set<ChatUser>?
    
    private var userData: Set<ChatUser>?
    private var cancellables = Set<AnyCancellable>()
    private var listener: ListenerRegistration?
    private var lastDocument: DocumentSnapshot?
    private let pageSize = 20
    private var isInitialMessage: Bool = true
    
 
    //새 채팅방 생성시
    init(userData: Set<ChatUser>?, chatRoom: ChatRoom?) {
        self.userData = userData
        self.chatRoom = chatRoom
        fetchUsersInfoByRoom()
    }

    
    //채팅방 목록으로 들어온 경우
    init(chatRoom room: ChatRoom) {
        self.userData = .init()
        self.chatRoom = room
        fetchUsersInfoByRoom()
    }
    
     
    deinit {
        listener?.remove()
    }
    
    //MARK: - 메시지 전송
    //새롭게 채팅방을 시작한 경우 여기서 부터 수정
    func sendMessageBySelectedUser() {
        guard let fromId = AuthManager.shared.id,
              let selectedUserIds = userData?.map({$0.uid})
              else { return }
        let participants = selectedUserIds + [fromId]
        let messageId = UUID().uuidString
        let timestamp = Timestamp(date: Date())
        
        var chatRoomData = ChatRoom()
        //기존 챗방 새로운 챗방 분기
        if let existingRoom = chatRoom, existingRoom.participantsJoinDates != nil {
            chatRoomData = existingRoom
        } else {
            chatRoomData = ChatRoom(
                chatRoomType:(participants.count > 2 ? .group : .direct) ,
                chatRoomId: chatRoom?.chatRoomId ?? UUID().uuidString,
                chatRoomMakerId: chatRoom?.chatRoomMakerId ?? fromId,
                participants: chatRoom?.participants ?? participants.sorted(by: {$0 < $1}),
                participantsJoinDates: participants.reduce(into: [String:Timestamp]()) { $0[$1] = timestamp },
                chatName: (chatRoom?.chatName ?? ""),
                lastMessage: chatText,                 
                lastMessageTimeStamp: timestamp,
                lastMessageSenderId: fromId
            )
        }
        let chatMessageData = ChatMessage(
            messageId: messageId,
            senderId: fromId,
            text: chatText,
            timeStamp: timestamp,
            readBy: []
        )
        
        DispatchQueue.main.async {
            self.chatText = ""
        }
        //이전채팅방 있는지 확인
        DatabaseManager.shared.checkChatRoomExists(chatRoomId: chatRoomData.chatRoomId)
            .flatMap({ exists -> AnyPublisher<Void, Error> in
                if !exists {
                    //채팅방 없는 경우
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
                DatabaseManager.shared.updateChatRoom(chatRoomId: chatRoomData.chatRoomId, chatMessageData: chatMessageData)
            })
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Send Message Error : \(error)")
                }
                if case .finished = completion {
                    self.chatRoom = chatRoomData
                }
            }, receiveValue: { _ in
                
            })
            .store(in: &cancellables)
    }

    
    //기존채팅방에서 메시지를 보내는 경우
    func sendMessageByRoomId() {
        guard let chatRoomId = chatRoom?.chatRoomId else { return }
        guard let senderId = AuthManager.shared.id else { return }
        let chatMessageData = ChatMessage(messageId: UUID().uuidString,
                                           senderId: senderId,
                                           text: chatText,
                                           timeStamp: Timestamp(date: Date()),
                                           readBy: [])

        DispatchQueue.main.async {
            self.chatText = ""
        }
        DatabaseManager.shared.storeChatMessageData(chatRoomId: chatRoomId, chatMessageData: chatMessageData)
            .flatMap( { _ in
                DatabaseManager.shared.updateChatRoom(chatRoomId: chatRoomId, chatMessageData: chatMessageData)
            })
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print("Send Message Error : \(error)")

                case .finished:
                     break
                     
                }
            }, receiveValue: { _ in
                
            })
            .store(in: &cancellables)
    }
    
    //MARK: - 공용 메서드
    func fetchUsersInfoByRoom() {
        guard let userIds = chatRoom?.participants else { return }
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
    
    func makeUsersInfoBySelectedUser() {
        guard let userData = self.userData else { return }
        self.usersInfo = Dictionary(uniqueKeysWithValues: userData.map {($0.uid, $0)})
    }
    
    
    func showLocalNotification(message msg: ChatMessage) {
        let content = UNMutableNotificationContent()
        content.title = usersInfo?[msg.senderId]?.displayName ?? "새로운 메시지"
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
    
    func addPropMessage(_ newMessage: ChatMessage) {
        let calendar = Calendar.current
        var message = newMessage
        let currentTimestamp = message.timeStamp.dateValue()
        let currentMessageSenderId = message.senderId
        
        if chatMessages.isEmpty {
            message.isFirstInDayGroup = true
            message.isFirstInTimeGroup = true
            message.isFromSameSender = false
        } else {
            let lastMessage = chatMessages.last!
            let lastTimestamp = lastMessage.timeStamp.dateValue()
            let lastMessageSenderId = lastMessage.senderId
            // 날짜 그룹
            message.isFirstInDayGroup = !calendar.isDate(currentTimestamp, inSameDayAs: lastTimestamp)
            // 1분 단위 그룹
            message.isFirstInTimeGroup = !calendar.isDate(currentTimestamp, equalTo: lastTimestamp, toGranularity: .minute)
            // 보낸이 그룹
            message.isFromSameSender = currentMessageSenderId == lastMessageSenderId
            
        }
        chatMessages.append(message)
    }

    func addPropMessage(_ messages: [ChatMessage]) -> [ChatMessage] {
        var processedMessages = messages
        let calendar = Calendar.current
        
        for i in 0..<processedMessages.count {
            let currentTimestamp = processedMessages[i].timeStamp.dateValue()
            let currentSenderId = processedMessages[i].senderId
            let isFirstMessage = (i == 0)
            
            //이전 메시지 비교
            let perviousTimestamp = isFirstMessage ? nil : processedMessages[i - 1].timeStamp.dateValue()
            let perviousSenderId = isFirstMessage ? nil :  processedMessages[i - 1].senderId
            
            //같은 날짜 확인
            if isFirstMessage || perviousTimestamp != nil && !calendar.isDate(currentTimestamp, inSameDayAs: perviousTimestamp!) {
                processedMessages[i].isFirstInDayGroup = true
            } else {
                processedMessages[i].isFirstInDayGroup = false
            }
            //같은 시간 확인
            if isFirstMessage || perviousTimestamp != nil && !calendar.isDate(currentTimestamp, equalTo: perviousTimestamp!, toGranularity: .minute){
                processedMessages[i].isFirstInTimeGroup = true
            } else {
                processedMessages[i].isFirstInTimeGroup = false
            }
            //같은 아이디 확인
            if isFirstMessage || perviousSenderId != nil && currentSenderId != perviousSenderId {
                processedMessages[i].isFromSameSender = false
            } else {
                processedMessages[i].isFromSameSender = true
            }
        }
        return processedMessages
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
        isInitialMessage = true
    }
    
    private func writingMessageKey() -> String {
        if let roomId = chatRoom?.chatRoomId {
            return "writingMessage_\(roomId)"
        }
        return "writingMessage"
    }
    
    func loadWritingMessages() {
        self.chatText = UserDefaults.standard.string(forKey: self.writingMessageKey()) ?? ""
    }
    
    func saveWritingMessages() {
        UserDefaults.standard.set(chatText, forKey: writingMessageKey())
    }
    
    func clearWritingMessages() {
        UserDefaults.standard.removeObject(forKey: writingMessageKey())
    }
    
    //MARK: - 메시지 가져오기
    func fetchInitialMessages(chatRoomId: String) {
        guard let uid = AuthManager.shared.id else { return }
        let messageRef = DatabaseManager.shared.db.collection("rooms")
            .document(chatRoomId)
            .collection("messages")
        let query: Query
        if let joinDate = chatRoom?.participantsJoinDates?[uid] {
            query = messageRef
                .whereField("timeStamp", isGreaterThanOrEqualTo: joinDate)
                .order(by: "timeStamp", descending: true)
                .limit(to: pageSize)
        } else {
            query = messageRef
                .order(by: "timeStamp", descending: true)
                .limit(to: pageSize)
        }
        query.getDocuments { snapshot, error in
            if let error = error {
                print("Firebase Error:\(error)")
                return
            }
            guard let documents = snapshot?.documents else { return }
            self.lastDocument = documents.last
            let message = Array(documents.compactMap({ try? $0.data(as: ChatMessage.self) }).reversed())
            self.chatMessages = self.addPropMessage(message)
            self.fetchMessagesStartListener(chatRoomId: chatRoomId)
        }
    }
    
    func fetchMessagesStartListener(chatRoomId: String) {
        listener = DatabaseManager.shared.db.collection("rooms").document(chatRoomId)
            .collection("messages")
            .whereField("timeStamp", isGreaterThan: Timestamp(date: Date()))
            .order(by: "timeStamp", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Firebase Listener Error:\(error)")
                    return
                }
                guard let snapshot = snapshot?.documentChanges else { return }
                snapshot.reversed().forEach { change in
                    if let msg = try? change.document.data(as: ChatMessage.self) {
                        switch change.type {
                        case .added:
                            if !(self.chatMessages.contains(where: {$0.messageId == msg.messageId})) {
                                self.addPropMessage(msg)
                            }
                        case .modified:
                            break
                        case .removed:
                            self.chatMessages.removeAll(where: { $0.messageId == msg.id})
                        }
                    }
                }
            }
    }
    
    func fetchMoreMessages(chatRoomId roomId: String) async throws -> Bool {
        guard let lastDoc = lastDocument else { return false }
        let query = DatabaseManager.shared.db.collection("rooms")
            .document(roomId).collection("messages")
            .order(by: "timeStamp", descending: true)
            .start(afterDocument: lastDoc)
            .limit(to: pageSize)
        let snapshot = try await query.getDocuments()
        guard !snapshot.documents.isEmpty else { return false }
        self.lastDocument = snapshot.documents.last
        
        await MainActor.run(body: {
            let newMessages = snapshot.documents.compactMap({ try? $0.data(as: ChatMessage.self) }).reversed()
            chatMessages.insert(contentsOf: newMessages, at: 0)
            chatMessages = addPropMessage(chatMessages)
        })
        return true
    }
    
    //MARK: - Concurrency로 변경해보기
    
    func fetchInitialMessages(chatRoomId: String) async {
        guard let uid = AuthManager.shared.id else { return }
        let messageRef = DatabaseManager.shared.db.collection("rooms")
            .document(chatRoomId).collection("messages")
        let query: Query
        if let joinDate = chatRoom?.participantsJoinDates?[uid] {
            query = messageRef
                .whereField("timeStamp", isGreaterThan: joinDate)
                .order(by: "timeStamp", descending: true)
                .limit(to: pageSize)
        } else {
            query = messageRef
                .order(by: "timeStamp", descending: true)
                .limit(to: pageSize)
        }
        do {
            let snapshot = try await query.getDocuments()
            let documents = snapshot.documents
            self.lastDocument = snapshot.documents.last
            let messages = Array(documents.compactMap{ try? $0.data(as: ChatMessage.self) }.reversed())
            self.chatMessages = self.addPropMessage(messages)
            self.fetchMessagesStartListener(chatRoomId: chatRoomId)
        } catch {
            print("Firebase Error: \(error.localizedDescription)")
        }
    }
    
    //수정해야함
    func fetchMoreMessages() {
        guard let chatRoomId = chatRoom?.chatRoomId else { return }
        DatabaseManager.shared.collectionChatMessages(chatRoomId: chatRoomId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Fetch initial Message Error :\(error)")
                }
                if case .finished = completion {
                    return
                }
            }, receiveValue: { message in
                self.chatMessages = self.addPropMessage(message)
            })
            .store(in: &cancellables)
    }
    
    //수정해야함
    func fetchStartRealTimeListener() {
        guard let chatRoomId = chatRoom?.chatRoomId else { return }
        listener = DatabaseManager.shared.db.collection("rooms").document(chatRoomId)
            .collection("messages")
            .whereField("timeStamp", isGreaterThan: Timestamp(date: Date()))
            .order(by: "timeStamp", descending: true)
            .addSnapshotListener { snapshot, error in
                if error != nil {
                    return
                }
                guard let snapshot = snapshot else { return }
                snapshot.documentChanges.reversed().forEach { change in
                    if change.type == .added, let msg = try? change.document.data(as: ChatMessage.self) {
                        if !(self.chatMessages.contains(where: {$0.messageId == msg.messageId})) {
                        }
                    }
                }
            }
    }
    
    //MARK: - 채팅방 인원 관리
    func leaveChatRoom() {
        guard let uid = AuthManager.shared.id,
              let roomId = chatRoom?.chatRoomId else { return }
        DatabaseManager.shared.deleteChatRoomParticipant(userId: uid, chatRoomIds: roomId)
            .flatMap { _ in
                DatabaseManager.shared.deleteChatRoomParticipantJoinDates(userId: uid, chatRoomIds: roomId)
            }
            .sink(receiveCompletion: { completion in
                if case .failure(let failure) = completion {
                    print("Firebase Error : \(failure)")
                }
                if case .finished = completion {
                    Task {
                        await self.refreshChatRoom(roomId)
                    }
                }
            }, receiveValue: { result in
                self.sendResultMessage()
            })
            .store(in: &cancellables)
    }
    
    func sendResultMessage() {
        guard let uid = AuthManager.shared.id,
              let usersInfo = usersInfo,
              let chatRoomId = chatRoom?.chatRoomId,
              let userName = usersInfo[uid]?.displayName else { return }
        let leaveText = "\(userName)님이 채팅방에서 나갔습니다."
        let resultMessage = ChatMessage(messageId: UUID().uuidString,
                                        senderId: "leave",
                                        text: leaveText,
                                        timeStamp: Timestamp(date: Date()),
                                        readBy: [])
        DatabaseManager.shared.storeChatMessageData(chatRoomId: chatRoomId , chatMessageData: resultMessage)
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
    
    func validateChatRoomMembers(users: Set<ChatUser>) -> Set<ChatUser> {
        guard let participants = chatRoom?.participants else { return [] }
        let participantsSet = Set(participants)
        let excludeUsers = users.filter { !participantsSet.contains($0.uid) }
        return excludeUsers
    }
    
    func joinChatRoom(users: Set<ChatUser>) {
        let userIds = users.map{$0.uid}
        guard let chatRoomId = chatRoom?.chatRoomId else { return }
        let chatRoomType = ((users.count + (chatRoom?.participants.count ?? 0)) > 2) ? chatRoomType.group : chatRoomType.direct
        DatabaseManager.shared.updateChatRoomParticipants(userIds: userIds, chatRoomId: chatRoomId)
            .flatMap({ _ in
                DatabaseManager.shared.updateChatRoomParticipantsJoinDates(userIds: userIds, chatRoomId: chatRoomId)
            })
            .flatMap({ _ in
                DatabaseManager.shared.updateChatRoomFieldInfo(chatRoomId: chatRoomId, field: "chatRoomType", value: chatRoomType)
            })
            .sink(receiveCompletion: { completion in
                if case .failure(let failure) = completion {
                    print("Firebase Error : \(failure)")
                }
                if case .finished = completion {
                    Task {
                        await self.refreshChatRoom(chatRoomId)
                    }
                }
            }, receiveValue: { [self] result in
                sendResultMessage(inviteUsers: users)
            })
            .store(in: &cancellables)
    }
    
    func refreshChatRoom(_ chatRoomId: String) async {
        let docRef = DatabaseManager.shared.db.collection("rooms").document(chatRoomId)
        self.chatRoom = try? await docRef.getDocument().data(as: ChatRoom.self)
        self.fetchUsersInfoByRoom()
    }
    
    func sendResultMessage(inviteUsers: Set<ChatUser>) {
        guard let uid = AuthManager.shared.id,
              let usersInfo = usersInfo,
              let chatRoomId = chatRoom?.chatRoomId else { return }
        let userName = usersInfo[uid]?.displayName
        let invitedUserNames = inviteUsers.map({$0.displayName})
        let addText = """
                      \(userName ?? "")님이 \(invitedUserNames.joined(separator: ","))님을 채팅방에 초대했습니다.
                      """
        let resultMessage = ChatMessage(messageId: UUID().uuidString,
                                        senderId: "join",
                                        text: addText,
                                        timeStamp: Timestamp(date: Date()),
                                        readBy: [""])
        DatabaseManager.shared.storeChatMessageData(chatRoomId: chatRoomId , chatMessageData: resultMessage)
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
