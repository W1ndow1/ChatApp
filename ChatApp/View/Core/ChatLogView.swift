import SwiftUI
import _PhotosUI_SwiftUI
import SDWebImageSwiftUI

struct ChatLogView: View {
    //겔러리 뷰 관련 속성
    @Namespace private var imageNamespace
    @State private var galleryImages: [GalleryImageItem] = []
    @State private var galleryStartIndex: Int = 0
    @State private var showGalleryView = false
    @State private var showNaviBar = false
    
    @StateObject var viewModel: ChatLogViewModel
    @StateObject var keyboardObserver = KeyboardStateObserver()
    @State private var navigationTitle = ""
    @State private var enterButtonText = "#"
    @State private var chatRoom: ChatRoom?
    @State private var isSendMessage = false
    @State private var isTop = false
    @State private var fromMessageListView = false
    @State private var debounceTask: Task<Void, Never>?
    @State private var showSideMenu = false
    @State private var isBottomMenuVisible = false
    @State private var hasOpenedBottomMenuOnce = false
    @Binding var hideTabBar: Bool
    @FocusState private var isFocused: Bool
    @State private var popupAlert = false
    @State private var keyboardHeight: CGFloat = 0
    
    private var userData: Set<ChatUser>?
    
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
                isPresented: $showSideMenu)
            /*
            CustomGalleryView(
                images: galleryImages,
                startIndex: galleryStartIndex,
                namespace: imageNamespace,
                isPresented: $showGalleryView)
             */
            CustomGalleryViewEx(
                images: galleryImages,
                startIndex: galleryStartIndex,
                isPresented: $showGalleryView
            )
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(showSideMenu || showGalleryView ? .hidden : .visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    hideKeyboard()
                    showSideMenu = true
                    Task {
                        guard let chatRoomId = viewModel.chatRoom?.chatRoomId else { return }
                        await viewModel.refreshChatRoom(chatRoomId)
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
                            messageContent(msg)
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
            //.background(Color.accentColor)
            .onTapGesture {
                if isBottomMenuVisible {
                    isBottomMenuVisible = false
                }
                hideKeyboard()
                hasOpenedBottomMenuOnce = false
            }
            .rotationEffect(.degrees(180))
            .scaleEffect(x: -1)
            .safeAreaInset(edge: .bottom){
                bottomInputView()
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
            case .text, .image, .images:
                ChatRoomMessageView(
                    viewModel: viewModel,
                    msg: msg,
                    imageNameSpace: imageNamespace) { images, startIndex in
                        galleryImages = images
                        galleryStartIndex = startIndex
                        showGalleryView = true
                    }
            case .leave, .join:
                chatRoomMemberStateMessage(msg: msg)
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
        if msg.isFirstInDayGroup {
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
    private func bottomInputView() -> some View {
        VStack {
            HStack(alignment: .bottom) {
                VStack {
                    Button {
                        //메뉴를 활성화 하는 버튼
                        if !hasOpenedBottomMenuOnce {
                            withAnimation(nil) {
                                isBottomMenuVisible = true
                                hasOpenedBottomMenuOnce = true
                            }
                            hideKeyboard()
                        } else {
                            isFocused.toggle()
                        }
                        
                    } label: {
                        Image(systemName: "photo.on.rectangle.angled")
                            .foregroundStyle(Color.primary)
                            .font(.system(size: 20))
                    }
                }
                .frame(height: 40)
                
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
                    .observeKeyboard($keyboardHeight)
                
                
                Button {
                    if !viewModel.chatText.isEmpty {
                        let sendAction: () = fromMessageListView
                        ? viewModel.sendMessageByRoomId()
                        : viewModel.sendMessageBySelectedUser()
                        sendAction
                        isSendMessage.toggle()
                    } else if viewModel.resizeData.count > 0 {
                        viewModel.selectedImage = []
                        viewModel.sendImages()
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
                .disabled(viewModel.chatText.isEmpty && viewModel.resizeData.count == 0)
                .onChange(of: viewModel.resizeData.count) { _ , new  in
                    enterButtonText = String(new)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom,5)
            .background(Color(.systemBackground))
            
            if isBottomMenuVisible {
                ChatRoomBottomMenuView(viewModel: viewModel)
                    .frame(height: keyboardHeight > 336 ? 345 : 300)
            }
        }
        .gesture(dragVGesture())
    }
    
    private func dragVGesture() -> some Gesture {
        DragGesture()
            .onChanged { value in
                if value.translation.height > 50 {
                    isBottomMenuVisible = false
                    hideKeyboard()
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
