import SwiftUI
import SDWebImageSwiftUI

struct ChatLogView: View {
    @StateObject var viewModel: ChatLogViewModel
    @State var navigationTitle = ""
    @State var enterButtonText = "#"
    @State var chatRoom: ChatRoom?
    @State var msgCount: Int = 0
    @State private var isSendMessage = false
    @State private var isTop = false
    @State private var fromMessageListView: Bool = false
    @State private var debounceTask: Task<Void, Never>?
    
    private var userData: Set<ChatUser>?
    
    //새 채팅방 생성으로 들어온 경우
    init(userData: Set<ChatUser>?, fromMessageListView: Bool = false) {
        self.userData = userData
        self.fromMessageListView = fromMessageListView
        self._viewModel = StateObject(wrappedValue: ChatLogViewModel(userData: userData))
    }
     
    
    //채팅방 목록으로 들어온 경우
    init(chatRoom: ChatRoom, fromMessageListView: Bool = true) {
        self.userData = .none
        self.fromMessageListView = fromMessageListView
        self.chatRoom = chatRoom
        self._viewModel = StateObject(wrappedValue: ChatLogViewModel(chatRoom: chatRoom))
    }
    
    var body: some View {
        ZStack {
            chatBubbleRow()
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    viewModel.fetchInitialMessages(chatRoomId: fromMessageListView
                                                            ? viewModel.chatRoom?.chatRoomId ?? ""
                                                            : viewModel.chatRoomId ?? "")
                    navigationTitleLengthCheck()
                }
                .onDisappear {
                    viewModel.stopListening()
                }
        }
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
                                if msg.senderId != AuthManager.shared.id {
                                    otherMessage(msg: msg)
                                } else {
                                    myMessage(msg: msg)
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
            .onTapGesture { hideKeyboard() }
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
    private func chatSection(msg: ChatMessage) -> some View {
        if msg.isFirstInDayGroup ?? false {
            HStack {
                Text(formatDataToYear(msg.timeStamp.dateValue()))
                    .padding(8)
                    .font(.system(size: 12, weight: .light))
                    .background(Color.gray.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.vertical, 20)
            .onTapGesture {
                print("🪛 Tab Calendar")
            }
        }
    }
    
    
    func shouldDisplayImage(current: String) {
        
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
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(minWidth: 30, alignment: .leading)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                    if (msg.isFirstInTimeGroup ?? false) || !(msg.isFromSameSender ?? false) {
                        Text(formatDataToTime(msg.timeStamp.dateValue()))
                            .font(.system(size: 10, weight: .light))
                    }
                    Spacer()
                }
                .padding(.vertical, 5)
            }
            .padding(.trailing, 50)
        }
        Spacer()
    }
    
    @ViewBuilder
    private func myMessage(msg: ChatMessage) -> some View {
        Spacer()
        HStack(alignment: .bottom) {
            Spacer()
            if (msg.isFirstInTimeGroup ?? false) || !(msg.isFromSameSender ?? false) {
                Text(formatDataToTime(msg.timeStamp.dateValue()))
                    .font(.system(size: 10, weight: .light))
            }
            Text(msg.text)
                .padding(8)
                .foregroundStyle(Color.white)
                .background(.tint)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(minWidth: 30, alignment: .trailing)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 5)
        .padding(.leading, 50)
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
                    Wv5HZZ3NMOQysA9VqEUdgdGQs713_
                    uBzmBwnRmdbkCFoBls9DHa4uC8j2
                    """, 
        chatRoomMakerId: "Wv5HZZ3NMOQysA9VqEUdgdGQs713",
        participants: ["Wv5HZZ3NMOQysA9VqEUdgdGQs713",
                       "uBzmBwnRmdbkCFoBls9DHa4uC8j2"],
        lastMessageTimeStamp: .init(date: Date()),
        lastMessageSenderId: "Wv5HZZ3NMOQysA9VqEUdgdGQs713")
    )
}

extension ChatLogView {
    
    private func loadMoreMessages() async {
         _ = try? await viewModel.fetchMoreMessages(chatRoomId: fromMessageListView
                                    ? viewModel.chatRoom?.chatRoomId ?? ""
                                    : viewModel.chatRoomId ?? "")
    }
    
    
    func formatDataToYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일"
        return formatter.string(from: date)
    }
    
    func formatDataToTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter.string(from: date)
    }
    
    func formatDateToString(_ date: Date, dateFormat: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = dateFormat
        return formatter.string(from: date)
    }
    
    func navigationTitleLengthCheck() {
        if fromMessageListView {
            navigationTitle = chatRoom?.chatName ?? ""
        } else {
            guard let userData = userData else { return }
            if userData.count < 4 {
                navigationTitle = userData.map({ $0.displayName }).joined(separator: ", ")
            } else {
                navigationTitle = userData.prefix(3).map({ $0.displayName }).joined(separator: ", ") + "..."
            }
        }
    }
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
