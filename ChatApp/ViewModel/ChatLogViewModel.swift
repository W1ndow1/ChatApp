import Foundation
import _PhotosUI_SwiftUI
import FirebaseFirestore
import Combine
import UserNotifications

class ChatLogViewModel: ObservableObject {
    @Published var chatText = ""
    @Published var chatRoom: ChatRoom?
    @Published var chatMessages: [ChatMessage] = []
    @Published var usersInfo: [String : ChatUser]?
    @Published var selectedUser: Set<ChatUser>?
    @Published var isCaptureIamge: Bool = false
    @Published var captureIamge: UIImage?
    @Published var loadedIamge: UIImage? = nil
    @Published var resizeData = [Data]()
    @Published var selectedImage = [PhotosPickerItem]() {
        didSet {
            Task {
                await prepareImage()
                print("변환갯수:\(resizeData.count)")
            }
        }
    }
    
    private var localMessages: [ChatMessage] = []
    private var serverMessages: [ChatMessage] = []
    
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
        NotificationCenter.default.removeObserver(self)
    }
    
    //MARK: - 메시지 전송
    func sendMessageBySelectedUser() {
        guard let fromId = AuthManager.shared.id,
              let selectedUserIds = userData?.map({$0.uid})
              else { return }
        let participants = selectedUserIds + [fromId]
        let messageId = UUID().uuidString
        let timestamp = Timestamp(date: Date())
        
        //기존 챗방 새로운 챗방 분기
        let chatRoomData: ChatRoom = {
            guard let existingRoom = chatRoom, existingRoom.participantsJoinDates != nil else {
                return ChatRoom(
                    chatRoomType:(participants.count > 2 ? .group : .direct) ,
                    chatRoomId: chatRoom?.chatRoomId ?? UUID().uuidString,
                    chatRoomMakerId: chatRoom?.chatRoomMakerId ?? fromId,
                    chatRoomImageUrl: chatRoom?.chatRoomImageUrl ?? "",
                    participants: chatRoom?.participants ?? participants.sorted(by: {$0 < $1}),
                    
                    participantsJoinDates: participants.reduce(into: [String:Timestamp]()) { $0[$1] = timestamp },
                    isCustomName: true,
                    chatName: (chatRoom?.chatName ?? ""),
                    lastMessage: chatText,
                    lastMessageTimeStamp: timestamp,
                    lastMessageSenderId: fromId
                )
            }
            return existingRoom
        }()
        
        let chatMessageData = ChatMessage(
            messageId: messageId,
            type: .text,
            senderId: fromId,
            text: chatText,
            timeStamp: timestamp,
            readBy: [],
            imageURLs: []
        )
        
        DispatchQueue.main.async { self.chatText = ""  }
        //이전채팅방 있는지 확인
        DatabaseManager.shared.checkChatRoomExists(chatRoomId: chatRoomData.chatRoomId)
            .flatMap { exists -> AnyPublisher<Void, Error> in
                exists 
                ? Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
                : DatabaseManager.shared.storeChatRoomData(chatRoomData: chatRoomData)
            }
            .flatMap { _ in
                DatabaseManager.shared.storeChatMessageData(chatRoomData: chatRoomData, chatMessageData: chatMessageData)
            }
            .flatMap { _ in
                DatabaseManager.shared.updateChatRoom(chatRoomId: chatRoomData.chatRoomId, chatMessageData: chatMessageData)
            }
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
                                          type: .text,
                                          senderId: senderId,
                                          text: chatText,
                                          timeStamp: Timestamp(date: Date()),
                                          readBy: [],
                                          imageURLs: [])

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
    
    //이미지 전송
    func sendImage() {
        guard let chatRoomId = chatRoom?.chatRoomId,
              let senderId = AuthManager.shared.id,
              let resizeImage = captureIamge?.resizeMaintainningRatio(toWidth: 1200),
              let imageData = resizeImage.jpegData(compressionQuality: 0.4)
        else { return }
        
        let tempMessageId = UUID().uuidString
        var sendingMessage = ChatMessage(
            messageId: tempMessageId,
            type: .image,
            senderId: senderId,
            text: "",
            timeStamp: Timestamp(date: Date()),
            readBy: [],
            imageURLs: [],
            sendState: .sending,
            )
        
        localMessages.append(sendingMessage)
        updateChatMessages()
        
        Task {
            do {
                let imageURL = try await StorageManager.shared.uploadChatRoomImage(image: imageData , chatRoomId: chatRoomId)
                await MainActor.run {
                    resizeData = []
                }
                
                //메시지 내용
                sendingMessage.text = imageURL.absoluteString
                sendingMessage.sendState = .sent
                
                let ref = DatabaseManager.shared.db
                    .collection("rooms").document(chatRoomId)
                    .collection("messages").document(sendingMessage.messageId)
                _ = ref.setData(from: sendingMessage)
                
                if let index = localMessages.firstIndex(where: { $0.messageId == tempMessageId }) {
                    localMessages.remove(at: index)
                    updateChatMessages()
                }
            } catch {
                print("이미지 전송 에러 \(error.localizedDescription)")
                if let index = localMessages.firstIndex(where: { $0.messageId == tempMessageId }) {
                    localMessages[index].sendState = .failed
                    updateChatMessages()
                }
            }
        }
    }
    
    //이미지 묶음 보내기
    func sendImages() {
        guard let chatRoomId = chatRoom?.chatRoomId,
              let senderId = AuthManager.shared.id
              else { return }
        let tempMessageId = UUID().uuidString
        var sendingMessage = ChatMessage(
            messageId: tempMessageId,
            type: (resizeData.count > 1 ? .images : .image),
            senderId: senderId,
            text: "",
            timeStamp: Timestamp(date: Date()),
            readBy: [],
            imageURLs: [],
            sendState: .sending,
            )
        localMessages.append(sendingMessage)
        updateChatMessages()
        
        Task {
            do {
                let uploadURLs = try await withThrowingTaskGroup(of: URL.self) { group in
                    for imageData in resizeData {
                        group.addTask {
                            return try await StorageManager.shared.uploadChatRoomImage(image: imageData, chatRoomId: chatRoomId)
                        }
                    }
                    var result = [String]()
                    for try await url in group {
                        result.append(url.absoluteString)
                    }
                    return result
                }
                
                await MainActor.run {
                    selectedImage = []
                    resizeData = []
                }
                
                sendingMessage.text = uploadURLs.count == 1 ? uploadURLs[0] : ""
                sendingMessage.imageURLs = uploadURLs.count > 1 ? uploadURLs : []
                sendingMessage.sendState = .sent
                
                let ref = DatabaseManager.shared.db
                    .collection("rooms").document(chatRoomId)
                    .collection("messages").document(sendingMessage.messageId)
                _ = ref.setData(from: sendingMessage)
                
                if let index = localMessages.firstIndex(where: { $0.messageId == tempMessageId }){
                    localMessages.remove(at: index)
                    updateChatMessages()
                }
            } catch {
                print("이미지 업로드 실패 : \(error.localizedDescription)")
                if let index = localMessages.firstIndex(where: { $0.messageId == tempMessageId }) {
                    localMessages[index].sendState = .failed
                    updateChatMessages()
                }
            }
        }
    }
    
    @MainActor
    func prepareImage() async {
        var newData = [Data]()
        for item in selectedImage {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    let resized = image.resizeMaintainningRatio(toWidth: 1200)
                    if let jpegData = resized.jpegData(compressionQuality: 0.4) {
                        newData.append(jpegData)
                    }
                }
            } catch {
                print("이미지 변환 실패 :\(error.localizedDescription)")
                AppError.shared.show(
                            """
                            이미지 변환에 실패했습니다.
                            공유된 이미지일 경우 카메라롤로 옮겨주세요.
                            \(error.localizedDescription)
                            """,
                            type: .validation)
            }
        }
        self.resizeData = newData
    }
    
    
    func chatRoomImageMerge() -> [GalleryImageItem] {
        var allImages = [GalleryImageItem]()
        for msg in chatMessages {
            let userName = usersInfo?[msg.senderId]?.displayName ?? "알 수 없는 사용자"
            if msg.type == .image {
                allImages.append(GalleryImageItem(
                    id: msg.id,
                    url: msg.text,
                    userName: userName,
                    sendDate: msg.timeStamp))
            } else if msg.type == .images {
                for url in msg.imageURLs {
                    allImages.append(GalleryImageItem(
                        id: UUID().uuidString,
                        url: url,
                        userName: userName,
                        sendDate: msg.timeStamp))
                }
            }
        }
        return allImages
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
    
    //메시지 처리
    func updateChatMessages() {
        let merged = (serverMessages + localMessages)
            .sorted(by: { $0.timeStamp.dateValue() < $1.timeStamp.dateValue() })
        DispatchQueue.main.async {
            self.chatMessages = self.addPropMessage(merged)
        }
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
    
    //채팅방 메시지 저장 및 로드
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
            //self.chatMessages = self.addPropMessage(message)
            self.serverMessages.append(contentsOf: message)
            self.updateChatMessages()
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
                                //self.addPropMessage(msg)
                                self.serverMessages.append(msg)
                                self.updateChatMessages()
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
            //chatMessages.insert(contentsOf: newMessages, at: 0)
            //chatMessages = addPropMessage(chatMessages)
            serverMessages.insert(contentsOf: newMessages, at: 0)
            updateChatMessages()
        })
        return true
    }
    
    func saveImageToPhotos() {
        guard let image = loadedIamge else { return }
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized || status == .limited {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            } else {
                print("포토라이브러리 접근 권한이 필요합니다.")
            }
        }
    }
    
    //MARK: - Concurrency
    
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
            }, receiveValue: { [weak self] _ in
                self?.sendResultMessage()
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
                                        type: .leave,
                                        senderId: "leave",
                                        text: leaveText,
                                        timeStamp: Timestamp(date: Date()),
                                        readBy: [],
                                        imageURLs: [])
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
        guard let participants = chatRoom?.participants else { return ([]) }
        let participantsSet = Set(participants)
        let excludeUsers = users.filter { !participantsSet.contains($0.uid) }
        return excludeUsers
    }
    
    func joinChatRoom(users: Set<ChatUser>) {
        guard let chatRoom = chatRoom else { return }
        let userIds = users.map{$0.uid}
        let chatRoomType: ChatRoomType = (users.count + (chatRoom.participants.count) > 2) ? .group : .direct
        
        //채팅방 이름 설정
        let selectedName = users.map(\.displayName).joined(separator: ",")
        let perviousName = chatRoom.participants.compactMap({usersInfo?[$0]?.displayName}).joined(separator: ",")
        let addName = [perviousName, selectedName].filter{!$0.isEmpty}.joined(separator: ",")
        let chatName = (chatRoomType == .group && chatRoom.isCustomName) ? chatRoom.chatName : addName
        
        DatabaseManager.shared.updateChatRoomParticipants(userIds: userIds, chatRoomId: chatRoom.chatRoomId)
            .flatMap({ _ in
                DatabaseManager.shared.updateChatRoomParticipantsJoinDates(userIds: userIds, chatRoomId: chatRoom.chatRoomId)
            })
            .flatMap({ _ in
                DatabaseManager.shared.updateChatRoomFieldInfo(chatRoomId: chatRoom.chatRoomId, field: "chatRoomType", value: chatRoomType.rawValue)
            })
            .flatMap({ _ in
                DatabaseManager.shared.updateChatRoomFieldInfo(chatRoomId: chatRoom.chatRoomId, field: "chatName", value: chatName)
            })
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print("Firebase Error: \(error)")
                case .finished:
                    Task { await self.refreshChatRoom(chatRoom.chatRoomId) }
                }
            }, receiveValue: { [weak self] _ in
                self?.sendResultMessage(inviteUsers: users)
            })
            .store(in: &cancellables)
    }
    
   
    func refreshChatRoom(_ chatRoomId: String) async {
        let docRef = DatabaseManager.shared.db.collection("rooms").document(chatRoomId)
        guard let chatRoom = try? await docRef.getDocument().data(as: ChatRoom.self) else { return }
        await MainActor.run {
            self.chatRoom = chatRoom
        }
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
                                        type: .join,
                                        senderId: "join",
                                        text: addText,
                                        timeStamp: Timestamp(date: Date()),
                                        readBy: [""],
                                        imageURLs: [])
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
