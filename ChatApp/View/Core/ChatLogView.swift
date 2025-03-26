import SwiftUI
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
    @State private var showSideMenuView = false
    @Binding var hideTabBar: Bool
    
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
                .onAppear {
                    navigationTitleLengthCheck()
                    guard let chatRoomId = viewModel.chatRoom?.chatRoomId else { return }
                    viewModel.fetchInitialMessages(chatRoomId: chatRoomId)
                }
                .onDisappear {
                    viewModel.stopListening()
                }
            ChatRoomSideMenuView(viewModel: viewModel, isShowing: $showSideMenuView)
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    self.showSideMenuView.toggle()
                }label: {
                    Image(systemName: "sidebar.right")
                }
            }
        }
        .toolbar(showSideMenuView ? .hidden: .visible, for: .navigationBar)
    }
    
    @ViewBuilder
    private func chatBubbleRow() -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack {
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, 
                                        value: geo.frame(in: .named("scroll")).minY)}
                    ForEach(viewModel.chatMessages) { msg in
                        Section(header: chatSection(msg: msg)) {
                            HStack {
                                switch msg.senderId {
                                case "leave", "join":
                                    chatRoomMemberStateMessage(msg: msg)
                                case AuthManager.shared.id:
                                    myMessage(msg: msg)
                                default:
                                    otherMessage(msg: msg)
                                }
                            }
                            .padding(.vertical, 4)
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
            .onTapGesture { self.hideKeyboard() }
            .rotationEffect(.degrees(180))
            .scaleEffect(x: -1)
            .safeAreaInset(edge: .bottom) { viewBottom(proxy: proxy) }
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
                .padding(.vertical, 5)
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
        .padding(.vertical, 5)
        .padding(.leading, 30)
    }

    
    @ViewBuilder
    private func viewBottom(proxy: ScrollViewProxy) -> some View {
        HStack {
            Button{
                
            } label: {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundStyle(Color.primary)
            }
            TextField("메시지", text: $viewModel.chatText, axis: .vertical)
                .foregroundStyle(Color.primary)
                .padding(8)
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
                .onChange(of: viewModel.chatText, { old, new in
                    enterButtonText = viewModel.chatText.count > 0 ? "⇧" : "#"
                })
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
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}


#Preview {
    ChatLogView(chatRoom: ChatRoom(
        chatRoomId: """
                    UyZOQtY9occyvmxpP82jr7QdEP12_
                    WDznGLHspLevJ0kgC9m783bUtWB3_
                    Wv5HZZ3NMOQysA9VqEUdgdGQs713_
                    uBzmBwnRmdbkCFoBls9DHa4uC8j2
                    """,
        chatRoomMakerId: "Wv5HZZ3NMOQysA9VqEUdgdGQs713",
        participants: ["Wv5HZZ3NMOQysA9VqEUdgdGQs713",
                       "uBzmBwnRmdbkCFoBls9DHa4uC8j2"],
        isGroup: false,
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
