import Foundation
import FirebaseFirestore
import Combine
import UserNotifications

class ChatLogViewModel: ObservableObject {
    @Published var chatText = ""
    @Published var chatMessages: [ChatMessage] = []
    @Published var chatRoom: ChatRoom?
    @Published var usersInfo: [String : ChatUser]?
    @Published var chatRoomId: String?
    @Published var selectedUser: Set<ChatUser>?
    @Published var isLeaveChatRoom: Bool = false
    
    private var userData: Set<ChatUser>?
    private var cancellables = Set<AnyCancellable>()
    private var listener: ListenerRegistration?
    private var lastDocument: DocumentSnapshot?
    private let pageSize = 20
    private var isInitialMessage: Bool = true
    private let messageSubject = PassthroughSubject<ChatMessage, Error>()
    
 
    //새 채팅방 생성시
    init(userData: Set<ChatUser>?) {
        self.userData = userData
        makeUsersInfoBySelectedUser()
        makeChatRoomIdBySelectedUser()
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
    
    //Combine으로 리스너 만들 때 사용
    func messageStream() {
        messageSubject
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Message stream Error:\(error)")
                }
            }, receiveValue: { [weak self] message in
                self?.addMessage(message)
                
            })
            .store(in: &cancellables)
    }
    
    
    
    //MARK: - 메시지 전송
    
    func sendMessageBySelectedUser() {
        guard let fromId = AuthManager.shared.id else { return }
        guard let selectedUsersId = userData?.map({$0.uid}) else { return }
        guard let chatName = userData?.map({$0.displayName}).joined(separator: ",") else { return }
        
        var participants = selectedUsersId
        participants.append(fromId)
        guard let receiverId = participants.count == 2 ? participants.first : "" else { return }
        
        let chatRoomId = participants.sorted(by: { $0 < $1 }).joined(separator: "_")
        let chatMessageData = ChatMessage(
            messageId: UUID().uuidString,
            senderId: fromId,
            receiverId: receiverId,
            text: chatText,
            timeStamp: Timestamp(date: Date()),
            readBy: []
        )
        
        let chatRoomData = ChatRoom(
            chatRoomId: chatRoomId,
            chatRoomMakerId: fromId,
            participants: participants.sorted(by: { $0 < $1 }),
            isGroup: (participants.count > 2),
            chatName: chatName,
            lastMessage: chatText,
            lastMessageTimeStamp: chatMessageData.timeStamp,
            lastMessageSenderId: fromId
        )
        self.chatText = ""
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
                
            })
            .store(in: &cancellables)
    }
    
    func sendMessageByRoomId() {
        guard let chatRoomId = chatRoom?.chatRoomId else { return }
        guard let senderId = AuthManager.shared.id else { return }
        let chatMessageData = ChatMessage(messageId: UUID().uuidString,
                                           senderId: senderId,
                                           text: chatText,
                                           timeStamp: Timestamp(date: Date()),
                                           readBy: [])
        self.chatText = ""
        DatabaseManager.shared.storeChatMessageData(chatRoomId: chatRoomId, chatMessageData: chatMessageData)
            .flatMap( { _ in
                DatabaseManager.shared.updateChatRoom(chatRoomId: chatRoomId, chatMessageData: chatMessageData)
            })
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
    
    func sendMessageByRoomIdTransection() {
        guard let chatRoomId = chatRoom?.chatRoomId,
              let senderId = AuthManager.shared.id else { return }
        let chatMessageData = ChatMessage(
            messageId: UUID().uuidString,
            senderId: senderId,
            text: chatText,
            timeStamp: Timestamp(date: Date()),
            readBy: []
        )
        self.chatText = ""
        if !(chatMessages.contains(where: { $0.messageId == chatMessageData.messageId })) {
            addMessage(chatMessageData)
            }
        // Codable 객체를 딕셔너리로 변환
        let messageDict: [String: Any]
        do {
            messageDict = try Firestore.Encoder().encode(chatMessageData)
        } catch {
            print("Encoding error: \(error)")
            return
        }
        
        DatabaseManager().db.runTransaction({ (transaction, errorPointer) -> Any? in
            let messageRef = DatabaseManager().db.collection("rooms")
                .document(chatRoomId)
                .collection("messages")
                .document(chatMessageData.messageId)
            
            transaction.setData(messageDict, forDocument: messageRef)
            
            let chatRoomRef = DatabaseManager().db.collection("rooms").document(chatRoomId)
            transaction.updateData([
                "lastMessage": chatMessageData.text,
                "lastMessageTimeStamp": chatMessageData.timeStamp,
                "lastMessageSenderId": chatMessageData.senderId
            ], forDocument: chatRoomRef)
            
            return nil
        }, completion: { (_, error) in
            if let error = error {
                print("Error Transaction: \(error)")
            }
        })
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
    
    func makeChatRoomIdBySelectedUser() {
        guard let fromId = AuthManager.shared.id, let userData = self.userData else { return }
        var selectedUserId = userData.map({$0.uid})
        selectedUserId.append(fromId)
        let roomId = selectedUserId.sorted(by: {$0 < $1}).joined(separator: "_")
        self.chatRoomId = roomId
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

    func formatDataToTime(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter.string(from: date)
    }
    
    func addMessage(_ newMessage: ChatMessage) {
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
            // 시간 그룹
            message.isFirstInTimeGroup = formatDataToTime(date: currentTimestamp) != formatDataToTime(date: lastTimestamp)
            // 보낸이 그룹
            message.isFromSameSender = currentMessageSenderId == lastMessageSenderId
            
        }
        chatMessages.append(message)
    }

    func processChatMessages(_ messages: [ChatMessage]) -> [ChatMessage] {
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
            if isFirstMessage || perviousTimestamp != nil && formatDataToTime(date: currentTimestamp) != formatDataToTime(date: perviousTimestamp!) {
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
        } else if let roomId = chatRoomId {
            return "writingMessage_\(roomId)"
        }
        return "writingMessage"
    }
    
    func loadWritingMessages() {
        chatText = UserDefaults.standard.string(forKey: writingMessageKey()) ?? ""
    }
    
    func saveWritingMessages() {
        UserDefaults.standard.set(chatText, forKey: writingMessageKey())
    }
    
    func clearWritingMessages() {
        UserDefaults.standard.removeObject(forKey: writingMessageKey())
    }
    
    //MARK: - 메시지 가져오기
    
    func fetchInitialMessages(chatRoomId: String) {
        let query = DatabaseManager.shared.db.collection("rooms").document(chatRoomId)
            .collection("messages")
            .order(by: "timeStamp", descending: true)
            .limit(to: pageSize)
        query.getDocuments { snapshot, error in
            if let error = error {
                print("Firebase Error:\(error)")
                return
            }
            guard let documents = snapshot?.documents else { return }
            self.lastDocument = documents.last
            let message = Array(documents.compactMap({ try? $0.data(as: ChatMessage.self) }).reversed())
            self.chatMessages = self.processChatMessages(message)
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
                                self.addMessage(msg)
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
            chatMessages = processChatMessages(chatMessages)
        })
        return true
    }
    
    //MARK: - Combine 변경 예정
    
    func fetchMoreMessageByCombine(completion: @escaping (Bool) -> Void) {
        guard let roomId = chatRoom?.chatRoomId, let lastDoc = lastDocument else {
            completion(false)
            return
        }
        DatabaseManager.shared.db.collection("rooms").document(roomId)
            .collection("messages").order(by: "timeStamp", descending: true)
            .start(afterDocument: lastDoc)
            .limit(to: pageSize)
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    completion(false)
                    return
                }
                self.lastDocument = snapshot?.documents.last
                var newMessages = [ChatMessage]()
                newMessages = documents.compactMap({try? $0.data(as: ChatMessage.self)}).reversed()
                self.chatMessages.insert(contentsOf: newMessages, at: 0)
                self.chatMessages = self.processChatMessages(self.chatMessages)
                completion(true)
            }
    }

    func fetchInitialMessagesByCombine() {
        guard let chatRoomId = chatRoom?.chatRoomId else { return }
        DatabaseManager.shared.collectionChatMessages(chatRoomId: chatRoomId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Fetch initial Message Error :\(error)")
                }
                if case .finished = completion {
                    self.startRealTimeListener()
                }
            }, receiveValue: { message in
                self.chatMessages = self.processChatMessages(message)
            })
            .store(in: &cancellables)
    }
    
    func startRealTimeListener() {
        guard let chatRoomId = chatRoom?.chatRoomId else { return }
        listener = DatabaseManager.shared.db.collection("rooms").document(chatRoomId)
            .collection("messages")
            .whereField("timeStamp", isGreaterThan: Timestamp(date: Date()))
            .order(by: "timeStamp", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    self.messageSubject.send(completion: .failure(error))
                    return
                }
                guard let snapshot = snapshot else { return }
                snapshot.documentChanges.reversed().forEach { change in
                    if change.type == .added, let msg = try? change.document.data(as: ChatMessage.self) {
                        if !(self.chatMessages.contains(where: {$0.messageId == msg.messageId})) {
                            self.messageSubject.send(msg)
                        }
                    }
                }
            }
        self.messageStream()
    }
    
    //MARK: - 채팅방 인원 관리
    func leaveChatRoom() {
        guard let uid = AuthManager.shared.id,
              let roomId = chatRoom?.chatRoomId else { return }
        DatabaseManager.shared.deleteChatRoomParticipant(userId: uid, chatRoomIds: roomId)
            .sink(receiveCompletion: { completion in
                if case .failure(let failure) = completion {
                    print("Firebase Error : \(failure)")
                }
                if case .finished = completion {
                    self.sendResultMessage()
                }
            }, receiveValue: { result in
                self.isLeaveChatRoom = result
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
    
    func joinChatRoom(users: Set<ChatUser>) {
        guard let participants = chatRoom?.participants,
              let chatRoomId = chatRoom?.chatRoomId else { return }
        let participantsSet = Set(participants)
        let excludeUsers = users.filter { !participantsSet.contains($0.uid) }
        let userIds = excludeUsers.map({$0.uid})
        DatabaseManager.shared.updateChatRoomPatricipants(userIds: userIds, chatRoomId: chatRoomId)
            .sink(receiveCompletion: { completion in
                if case .failure(let failure) = completion {
                    print("Firebase Error : \(failure)")
                }
            }, receiveValue: { [self] result in
                sendResultMessage(inviteUsers: excludeUsers)
            })
            .store(in: &cancellables)
        
        
        /*
         <채팅방에 초대 하기 기능 만들기>
         (1)초대 하는 사용자가 기존 채팅방에 있는지 확인하기 excludeSeletedUsers()   -check
         (2)이후 채팅방 paticipants에 정보 넣기                               -check
         (3)초대했다는 메시지를 채팅방에 넣어주기 => 초대한 사람이름으로               -check
         (4)채팅방 목록에 리스너 동작하는지 확인해보기
         @@@앞으로 3인 이상의 단체 채팅방 제작시 이전 정보 가져오지 않게 한다. 3인 이상시 UUID로 변경
         
         */
        
    }
    
    func sendResultMessage(inviteUsers: Set<ChatUser>) {
        guard let uid = AuthManager.shared.id,
              let usersInfo = usersInfo,
              let chatRoomId = chatRoom?.chatRoomId else { return }
        let userName = usersInfo[uid]?.displayName
        let invitedUserNames = inviteUsers.map({$0.displayName})
        let addText = """
                      \(userName ?? "")님이
                      \(invitedUserNames.joined(separator: ","))님을 채팅방에 초대했습니다.
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
