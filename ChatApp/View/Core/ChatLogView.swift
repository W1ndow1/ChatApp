import SwiftUI
import _PhotosUI_SwiftUI
import SDWebImageSwiftUI

struct ChatLogView: View {
    @StateObject var viewModel: ChatLogViewModel
    @State private var navigationTitle = ""
    @State private var enterButtonText = "#"
    @State private var chatRoom: ChatRoom?
    @State private var isSendMessage = false
    @State private var isTop = false
    @State private var fromMessageListView: Bool = false
    @State private var debounceTask: Task<Void, Never>?
    @State private var showSideMenu = false
    @State private var isBottomMenuVisible = false
    @State private var hasOpenedBottomMenuOnce = false
    @Binding var hideTabBar: Bool
    @FocusState private var isFocused: Bool
    @StateObject var keyboardObserver = KeyboardStateObserver()
    @State private var bottomMenuState: BottomMenuState =  .initial
    
    private var userData: Set<ChatUser>?
    
    enum BottomMenuState {
        case initial
        case visible
        case hidden
    }
    
    //새 채팅방 생성으로 들어온 경우
    init(_ userData: Set<ChatUser>?,
         _ chatRoom: ChatRoom?,
         fromMessageListView: Bool = false,
         hideTabBar: Binding<Bool> = .constant(true)) {
        self.userData = userData
        self.fromMessageListView = fromMessageListView
        self._hideTabBar = hideTabBar
        self._viewModel = StateObject(wrappedValue: ChatLogViewModel(userData: userData, chatRoom: chatRoom))
    }
     
    
    //채팅방 목록으로 들어온 경우
    init(chatRoom: ChatRoom, fromMessageListView: Bool = true, hideTabBar: Binding<Bool> = .constant(true)) {
        self.userData = .none
        self.fromMessageListView = fromMessageListView
        self.chatRoom = chatRoom
        self._hideTabBar = hideTabBar
        self._viewModel = StateObject(wrappedValue: ChatLogViewModel(chatRoom: chatRoom))
    }
    
    var body: some View {
        ZStack {
            chatBubbleRow()
            ChatRoomSideMenuView(
                viewModel: viewModel,
                isShowSelectUserView: $showSideMenu)
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(showSideMenu ? .hidden : .visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    hideKeyboard()
                    showSideMenu = true
                    Task {
                        await viewModel.refreshChatRoom(chatRoom?.chatRoomId ?? "")
                    }
                }label: {
                    Image(systemName: "sidebar.right")
                }
            }
        }
        .onAppear {
            navigationTitleLengthCheck()
            guard let chatRoomId = viewModel.chatRoom?.chatRoomId else { return }
            viewModel.fetchInitialMessages(chatRoomId: chatRoomId)
        }
        .onDisappear {
            viewModel.stopListening()
        }
    }
    
    
    @ViewBuilder
    private func chatBubbleRow() -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack {
                    GeometryReader { geo in
                        Color
                            .clear
                            .preference(key: ScrollOffsetPreferenceKey.self,
                                        value: geo.frame(in: .named("scroll")).minY)}
                    ForEach(viewModel.chatMessages) { msg in
                        Section(header: chatSection(msg: msg)) {
                            HStack {
                                messageContent(msg)
                            }
                            .padding(.vertical, 2)
                            .padding(.horizontal, 8)
                        }
                        .id(msg.id)
                        .onAppear {
                            if msg.id == viewModel.chatMessages.last?.id && isSendMessage  {
                                proxy.scrollTo(msg.id)
                            }
                        }
                    }
                }
                .rotationEffect(.degrees(180))
                .scaleEffect(x: -1)
            }
            .defaultScrollAnchor(.top)
            .background(Color(white: 0.3, opacity: 0.1))
            .onTapGesture {
                if isBottomMenuVisible {
                    isBottomMenuVisible = false
                }
                hasOpenedBottomMenuOnce = false
                hideKeyboard()
            }
            .rotationEffect(.degrees(180))
            .scaleEffect(x: -1)
            .safeAreaInset(edge: .bottom){
                bottomInputView()
                    //.offset(y: viewModel.keyboardHeight > 0 && !isBottomMenuVisible ? -viewModel.keyboardHeight : 0 )
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                debounceTask?.cancel()
                debounceTask = Task {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if value > -10 && !isTop {
                        isTop = true
                        Task {
                            await loadMoreMessages()
                        }
                    } else if value <= -10 {
                        isTop = false
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func messageContent(_ msg: ChatMessage) -> some View {
        HStack {
                switch msg.type {
                case .text:
                    if msg.senderId != AuthManager.shared.id {
                        otherMessage(msg: msg)
                    } else {
                        myMessage(msg: msg)
                    }
                case .leave, .join:
                    chatRoomMemberStateMessage(msg: msg)
                case .image:
                    imageMessage(msg: msg)
                default:
                    EmptyView()
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
    }
    
    @ViewBuilder
    private func chatRoomMemberStateMessage(msg: ChatMessage) -> some View {
        HStack(alignment: .center) {
            Text(msg.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .font(.system(size: 12, weight: .light))
                .background(Color.gray.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }
 
    @ViewBuilder
    private func chatSection(msg: ChatMessage) -> some View {
        if msg.isFirstInDayGroup ?? false {
            HStack {
                Text(msg.timeStamp.dateValue().toString(dateFormat: "yyyy년 M월 d일 (E)"))
                    .padding(10)
                    .font(.system(size: 12, weight: .light))
                    .background(Color.gray.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.vertical, 20)
            .onTapGesture {
                print("🪛 Tab Calendar")
            }
        }
    }
    
    @ViewBuilder
    private func imageMessage(msg: ChatMessage) -> some View {
        HStack(alignment: .top) {
            if (msg.isFirstInTimeGroup ?? false) || !(msg.isFromSameSender ?? false) {
                WebImage(url: URL(string: viewModel.usersInfo?[msg.senderId]?.profileImageURL ?? ""))
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .foregroundStyle(Color.clear)
                    .frame(width:35)
            }
            VStack(alignment: .leading) {
                if (msg.isFirstInTimeGroup ?? false) || !(msg.isFromSameSender ?? false) {
                    Text(viewModel.usersInfo?[msg.senderId]?.displayName ?? "")
                        .font(.system(size: 10, weight: .light))
                }
                HStack(alignment: .bottom) {
                    WebImage(url: URL(string: msg.text))
                        .resizable()
                        .scaledToFill()
                    if (msg.isFirstInTimeGroup ?? false) || !(msg.isFromSameSender ?? false) {
                        Text(msg.timeStamp.dateValue().toString(dateFormat: "a h:mm"))
                            .font(.system(size: 10, weight: .light))
                    }
                    Spacer()
                }
            }
        }
    }
    
    @ViewBuilder
    private func otherMessage(msg: ChatMessage) -> some View {
        HStack(alignment: .top) {
            if (msg.isFirstInTimeGroup ?? false) || !(msg.isFromSameSender ?? false) {
                WebImage(url: URL(string: viewModel.usersInfo?[msg.senderId]?.profileImageURL ?? ""))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 35, height: 35)
                    .clipShape(Circle())
            } else {
                Rectangle()
                    .foregroundStyle(Color.clear)
                    .frame(width:35)
            }
            VStack(alignment: .leading) {
                if (msg.isFirstInTimeGroup ?? false) || !(msg.isFromSameSender ?? false) {
                    Text(viewModel.usersInfo?[msg.senderId]?.displayName ?? "")
                        .font(.system(size: 10, weight: .light))
                }
                HStack(alignment: .bottom) {
                    Text(msg.text)
                        .padding(8)
                        .background(Color.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .frame(minWidth: 30, alignment: .leading)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                    if (msg.isFirstInTimeGroup ?? false) || !(msg.isFromSameSender ?? false) {
                        Text(msg.timeStamp.dateValue().toString(dateFormat: "a h:mm"))
                            .font(.system(size: 10, weight: .light))
                    }
                    Spacer()
                }
                .padding(.vertical, 3)
            }
            .padding(.trailing, 30)
        }
        Spacer()
    }
    
    @ViewBuilder
    private func myMessage(msg: ChatMessage) -> some View {
        Spacer()
        HStack(alignment: .bottom) {
            Spacer()
            if (msg.isFirstInTimeGroup ?? false) || !(msg.isFromSameSender ?? false) {
                Text(msg.timeStamp.dateValue().toString(dateFormat: "a h:mm"))
                    .font(.system(size: 10, weight: .light))
            }
            Text(msg.text)
                .padding(8)
                .foregroundStyle(Color.white)
                .background(.tint)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .frame(minWidth: 30, alignment: .trailing)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
        }
        .padding(.leading, 30)
    }


    @ViewBuilder
    private func bottomInputView() -> some View {
        VStack {
            HStack {
                Button {
                    //메뉴를 활성화 하는 버튼
                    if !hasOpenedBottomMenuOnce {
                        hideKeyboard()
                        isBottomMenuVisible = true
                        hasOpenedBottomMenuOnce = true
                    } else {
                        isFocused.toggle()
                    }
                    
                } label: {
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundStyle(Color.primary)
                }
                
                TextField("메시지", text: $viewModel.chatText, axis: .vertical)
                    .focused($isFocused)
                    .foregroundStyle(Color.primary)
                    .padding(8)
                    .textFieldStyle(PlainTextFieldStyle())
                    .overlay(content: {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.primary, lineWidth: 0.8)
                    })
                    .onAppear {
                        viewModel.loadWritingMessages()
                        
                    }
                    .onDisappear {
                        if viewModel.chatText.count > 0 {
                            viewModel.saveWritingMessages()
                        } else {
                            viewModel.clearWritingMessages()
                        }
                    }
                    .onChange(of: viewModel.chatText) { _, new in
                        enterButtonText = new.count > 0 ? "⇧" : "#"
                        isFocused = true
                        
                    }
                    .onChange(of: keyboardObserver.isKeyboardVisible && !isBottomMenuVisible) { _, _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isBottomMenuVisible = keyboardObserver.keyboardHeight > 75
                        }
                    }
                    .onSubmit {
                        if !viewModel.chatText.isEmpty {
                            let sendAction: () = fromMessageListView
                            ? viewModel.sendMessageByRoomId()
                            : viewModel.sendMessageBySelectedUser()
                            sendAction
                            isSendMessage.toggle()
                            isFocused = true
                        }
                    }
                Button {
                    if !viewModel.chatText.isEmpty {
                        let sendAction: () = fromMessageListView
                        ? viewModel.sendMessageByRoomId()
                        : viewModel.sendMessageBySelectedUser()
                        sendAction
                        isSendMessage.toggle()
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .frame(width: 40, height: 40)
                        Text(enterButtonText)
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundStyle(Color.white)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 5)
            .padding(.bottom, 10)
            .background(Color(.systemBackground))
            
            if isBottomMenuVisible {
                ChatRoomBottomMenuView(viewModel: viewModel)
                    .frame(height: 300)
                    .transition(.move(edge: .bottom))
            }
            
        }
    }
}


#Preview {
    ChatLogView(chatRoom: ChatRoom(
        chatRoomType: .group,
        chatRoomId: """
                    UyZOQtY9occyvmxpP82jr7QdEP12_
                    WDznGLHspLevJ0kgC9m783bUtWB3_
                    Wv5HZZ3NMOQysA9VqEUdgdGQs713_
                    uBzmBwnRmdbkCFoBls9DHa4uC8j2
                    """,
        chatRoomMakerId: "Wv5HZZ3NMOQysA9VqEUdgdGQs713",
        participants: ["Wv5HZZ3NMOQysA9VqEUdgdGQs713",
                       "uBzmBwnRmdbkCFoBls9DHa4uC8j2"],
        chatName: "Malone,지구본,Time",
        lastMessageTimeStamp: .init(date: Date()),
        lastMessageSenderId: "Wv5HZZ3NMOQysA9VqEUdgdGQs713")
    )
}

extension ChatLogView {
    
    private func loadMoreMessages() async {
        guard let chatRoomId = viewModel.chatRoom?.chatRoomId else { return }
        do {
            _ = try await viewModel.fetchMoreMessages(chatRoomId: chatRoomId)
        } catch {
            print("메시지 로딩 실패:  \(error.localizedDescription)")
        }
    }
    
    private func navigationTitleLengthCheck() {
        if fromMessageListView {
            navigationTitle = chatRoom?.chatName ?? ""
        } else {
            navigationTitle = viewModel.chatRoom?.chatName ?? ""
        }
    }
}
