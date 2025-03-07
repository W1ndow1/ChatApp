import Foundation
import FirebaseFirestore
import Combine
import UserNotifications

class ChatLogViewModel: ObservableObject {
    @Published var chatText = ""
    @Published var chatMessages: [ChatMessages] = []
    @Published var chatRoom: ChatRooms?
    @Published var fromMessageListView: Bool = true
    @Published var usersInfo: [String : ChatUser]?
    @Published var chatRoomId: String?
    
    private var userData: Set<ChatUser>?
    private var cancellables = Set<AnyCancellable>()
    private var listener: ListenerRegistration?
    private var lastDocument: DocumentSnapshot?
    private let pageSize = 20
    private var isInitialMessage: Bool = true
    private let messageSubject = PassthroughSubject<ChatMessages, Error>()
    
 
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
        //fetchRecentMessageByRoomId()
    }
     
     
    
    deinit {
        listener?.remove()
    }
    
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
        let chatMessageData = ChatMessages(messageId: UUID().uuidString,
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
    
    func sendMessageByRoomId2() {
        guard let chatRoomId = chatRoom?.chatRoomId,
              let senderId = AuthManager.shared.id else { return }
        let chatMessageData = ChatMessages(
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
                "lastMessageTimeStamp": chatMessageData.timeStamp
            ], forDocument: chatRoomRef)
            
            return nil
        }, completion: { (_, error) in
            if let error = error {
                print("Error Transaction: \(error)")
            }
        })
    }
    
    
    
    
    //MARK: - 메시지 조회
    
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
    
    
    func fetchMessagesBySelectedUser() {
        guard let fromId = AuthManager.shared.id else { return }
        var selectedUserId = (userData?.map({$0.uid}))
        selectedUserId?.append(fromId)
        guard let chatRoomId = selectedUserId?.sorted(by: {$0 < $1}).joined(separator: "_") else { return }
        DatabaseManager.shared.db.collection("rooms").document(chatRoomId)
            .collection("messages")
            .order(by: "timeStamp", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("FireStore Error:\(error.localizedDescription)")
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
                        self.chatMessages.removeAll(where: {$0.messageId == removeChatMessageId})
                        break;
                    }
                }
            }
    }
    
    func fetchMessagesByRoomId() {
        guard let chatRoomId = chatRoom?.chatRoomId else { return }
        guard listener == nil else { return }
        listener = DatabaseManager.shared.db.collection("rooms").document(chatRoomId)
            .collection("messages")
            .order(by: "timeStamp", descending: false)
            .limit(to: 20)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("🔥Firestore Error:\(error.localizedDescription)")
                    return
                }
                self.lastDocument = snapshot?.documents.last
                snapshot?.documentChanges.forEach { change in
                    if let msg = try? change.document.data(as: ChatMessages.self) {
                        switch change.type {
                        case .added :
                            if !(self.chatMessages.contains(where: {$0.messageId == msg.messageId})) {
                                self.addMessage(msg)
                            }
                        case .modified:
                            if let index = self.chatMessages.firstIndex(where: { $0.messageId == msg.messageId }) {
                                self.chatMessages[index] = msg
                            }
                        case .removed:
                            self.chatMessages.removeAll(where: { $0.messageId == msg.messageId})
                        }
                    }
                }
            }
    }
    
    //MARK: - 공용 메서드
    
    func makeUserInfo() {
        guard let userData = self.userData else { return }
        self.usersInfo = Dictionary(uniqueKeysWithValues: userData.map {($0.uid, $0)})
    }
    
    func makeSelectedUserChatRoomId() {
        guard let fromId = AuthManager.shared.id else { return }
        var selectedUserId = (userData?.map({$0.uid}))
        selectedUserId?.append(fromId)
        if let roomId = selectedUserId?.sorted(by: {$0 < $1}).joined(separator: "_") {
            self.chatRoomId = roomId
        }
    }
    
    func addMessage(_ newMessage: ChatMessages) {
        if !(chatMessages.contains(where: {$0.id == newMessage.id})) {
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
                message.isFirstInTimeGroup = formatDataToTime(date: currentTimestamp) != formatDataToTime(date: lastTimestamp)
            }
            chatMessages.append(message)
        }
    }
    
    func showLocalNotification(message msg: ChatMessages) {
        let content = UNMutableNotificationContent()
        content.title = "새 메시지"
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
    
    func processChatMessages(_ messages: [ChatMessages]) -> [ChatMessages] {
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
            if isFirstMessage || perviousTimestamp != nil && formatDataToTime(date: currentTimestamp) != formatDataToTime(date: perviousTimestamp!) {
                processedMessages[i].isFirstInTimeGroup = true
            } else {
                processedMessages[i].isFirstInTimeGroup = false
            }
        }
        return processedMessages
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
        isInitialMessage = true
    }
    
    //MARK: - 메시지 동적 로드
    func fetchRecentMessageByRoomId() {
        guard let roomId = chatRoom?.chatRoomId, listener == nil else { return }
        listener = DatabaseManager.shared.db.collection("rooms").document(roomId)
            .collection("messages").order(by: "timeStamp", descending: true)
            .limit(to: pageSize)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Firebase error:\(error)")
                    return
                }
                self.lastDocument = snapshot?.documents.last
                snapshot?.documentChanges.reversed().forEach { change in
                    if let msg = try? change.document.data(as: ChatMessages.self) {
                        switch change.type {
                        case .added:
                            if !(self.chatMessages.contains(where: {$0.messageId == msg.messageId})) {
                                self.addMessage(msg)
                            }
                        case .modified:
                            break;
                        case .removed:
                            self.chatMessages.removeAll(where: { $0.messageId == msg.messageId})
                        }
                    }
                }
            }
    }
    
    func fetchMoreMessagesByRoomId(completion: @escaping (Bool) -> Void) {
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
                var newMessages = [ChatMessages]()
                newMessages = documents.compactMap({try? $0.data(as: ChatMessages.self)}).reversed()
                self.chatMessages.insert(contentsOf: newMessages, at: 0)
                self.chatMessages = self.processChatMessages(self.chatMessages)
                completion(true)
            }
    }
    
    func fetchMoreMessagesByRoomId2() async throws -> Bool {
        guard let roomId = chatRoom?.chatRoomId, let lastDoc = DatabaseManager.shared.lastDocument else {
            return false
        }
        let query = DatabaseManager.shared.db.collection("rooms")
            .document(roomId).collection("messages")
            .order(by: "timeStamp", descending: true)
            .start(afterDocument: lastDoc)//확인하기
            .limit(to: pageSize)
        
        let snapshot = try await query.getDocuments()
        guard !snapshot.documents.isEmpty else { return false }
        
        await MainActor.run(body: {
            self.lastDocument = snapshot.documents.last
            let newMessages = snapshot.documents.compactMap({ try? $0.data(as: ChatMessages.self) }).reversed()
            chatMessages.insert(contentsOf: newMessages, at: 0)
            chatMessages = processChatMessages(chatMessages)
        })
        return true
    }

    func fetchRecentMessagesBySelectedUser() {
        makeUserInfo()
        makeSelectedUserChatRoomId()
        guard let roomId = self.chatRoomId, listener == nil else { return }
        listener = DatabaseManager.shared.db.collection("rooms").document(roomId)
            .collection("messages").order(by: "timeStamp", descending: true)
            .limit(to: pageSize)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Firebase error:\(error)")
                    return
                }
                self.lastDocument = snapshot?.documents.last
                snapshot?.documentChanges.reversed().forEach { change in
                    switch change.type {
                    case .added:
                        if let msg = try? change.document.data(as: ChatMessages.self) {
                            self.addMessage(msg)
                        }
                    case .modified:
                        break;
                    case .removed:
                        break;
                    }
                }
            }
    }
    
    func fetchMoreMessagesBySelectedUser(completion: @escaping (Bool) -> Void) {
        guard let roomId = self.chatRoomId, let lastDoc = lastDocument else {
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
                var newMessages = [ChatMessages]()
                newMessages = documents.compactMap({try? $0.data(as: ChatMessages.self)}).reversed()
                self.chatMessages.insert(contentsOf: newMessages, at: 0)
                self.chatMessages = self.processChatMessages(self.chatMessages)
                completion(true)
            }
    }
    
    func fetchMoreMessagesBySelectedUser2() async throws -> Bool{
        guard let roomId = self.chatRoomId, let lastDoc = lastDocument else {
            return false
        }
        let query = DatabaseManager.shared.db.collection("rooms")
            .document(roomId).collection("messages")
            .order(by: "timeStamp", descending: true)
            .start(afterDocument: lastDoc)
            .limit(to: pageSize)
        let snapshot = try await query.getDocuments()
        guard !snapshot.documents.isEmpty else { return false }
        
        await MainActor.run {
            lastDocument = snapshot.documents.last
            let newMessages = snapshot.documents.compactMap({ try? $0.data(as: ChatMessages.self)}).reversed()
            self.chatMessages.insert(contentsOf: newMessages, at: 0)
            self.chatMessages = processChatMessages(chatMessages)
        }
        return true
    }
    
    func fetchInitialMessagesByRoomId() {
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
            .order(by: "timeStamp", descending: true)
            .limit(to: 1)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    self.messageSubject.send(completion: .failure(error))
                    return
                }
                guard let snapshot = snapshot else { return }
                snapshot.documentChanges.reversed().forEach { change in
                    if change.type == .added, let msg = try? change.document.data(as: ChatMessages.self) {
                        if !(self.chatMessages.contains(where: {$0.messageId == msg.messageId})) {
                            self.messageSubject.send(msg)
                        }
                    }
                }
            }
        self.messageStream()
    }
}
