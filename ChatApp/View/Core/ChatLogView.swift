import SwiftUI
import SDWebImageSwiftUI

struct ChatLogView: View {
    @StateObject var viewModel: ChatLogViewModel
    @State var navigationTitle = ""
    @State var enterButtonText = "#"
    @State var chatRoomName = ""
    @State var msgCount: Int = 0
    @State private var isLoadingMore = false
    
    private var userData: Set<ChatUser>?
    
    //새 채팅방 생성으로 들어온 경우
    init(userData: Set<ChatUser>?) {
        self.userData = userData
        self._viewModel = StateObject(wrappedValue: ChatLogViewModel(userData: userData))
    }
     
    
    //채팅방 목록으로 들어온 경우
    init(chatRoom: ChatRooms, chatRoomName: String) {
        self.userData = .none
        self.chatRoomName = chatRoomName
        self._viewModel = StateObject(wrappedValue: ChatLogViewModel(chatRoom: chatRoom))
    }
    
    var body: some View {
        ZStack {
            chatBubbleRow()
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    navigationTitleLengthCheck()
                    viewModel.fetchInitialMessagesByRoomId()
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
                    ForEach(viewModel.chatMessages) { msg in
                        Color.clear
                            .frame(height: 1)
                            .background(
                                 GeometryReader { geo in
                                     Color.clear.preference(key: ScrollOffsetPreferenceKey.self, 
                                                            value: geo.frame(in: .named("scroll")).minY)
                                 }
                            )
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
                            if msg.id == viewModel.chatMessages.last?.id {
                                proxy.scrollTo(msg.id, anchor: .bottom)
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
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                print(value)
                if value == 0 && !isLoadingMore {
                    Task { await loadMoreMessages2() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack{
                    Text("\(viewModel.chatMessages.count) 개")
                    viewBottom(proxy: proxy)
                }
            }
        }
    }
    
    @ViewBuilder
    private func chatSection(msg: ChatMessages) -> some View {
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
    
    @ViewBuilder
    private func otherMessage(msg: ChatMessages) -> some View {
        HStack(alignment: .top) {
            if (msg.senderId != AuthManager.shared.id) && (msg.isFirstInTimeGroup ?? false) {
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
                if msg.isFirstInTimeGroup ?? false {
                    Text(viewModel.usersInfo?[msg.senderId]?.displayName ?? "")
                        .font(.system(size: 10, weight: .ultraLight))
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
                    if msg.isFirstInTimeGroup ?? false {
                        Text(formatDataToTime(msg.timeStamp.dateValue()))
                            .font(.system(size: 10, weight: .light))
                    }
                    Spacer()
                }
            }
        }
        Spacer()
    }
    
    @ViewBuilder
    private func myMessage(msg: ChatMessages) -> some View {
        Spacer()
        HStack(alignment: .bottom) {
            Spacer()
            if msg.isFirstInTimeGroup ?? false {
                Text(formatDataToTime(msg.timeStamp.dateValue()))
                    .font(.system(size: 10, weight: .ultraLight))
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
                    let sendAction: () = viewModel.fromMessageListView
                    ? viewModel.sendMessageByRoomId()
                    : viewModel.sendMessage()
                    DispatchQueue.main.async {
                        sendAction
                        proxy.scrollTo("Bottom", anchor: .bottom)
                    }
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
    ChatLogView(chatRoom: ChatRooms(
        chatRoomId: "UyZOQtY9occyvmxpP82jr7QdEP12_WDznGLHspLevJ0kgC9m783bUtWB3_Wv5HZZ3NMOQysA9VqEUdgdGQs713_uBzmBwnRmdbkCFoBls9DHa4uC8j2",
        participants: ["UyZOQtY9occyvmxpP82jr7QdEP12","WDznGLHspLevJ0kgC9m783bUtWB3","Wv5HZZ3NMOQysA9VqEUdgdGQs713","uBzmBwnRmdbkCFoBls9DHa4uC8j2"],
        lastMessageTimeStamp: .init(date: Date())), chatRoomName: "홍길동")
}

extension ChatLogView {
   
    private func loadMoreMessages(_ proxy: ScrollViewProxy) {
        guard !isLoadingMore else { return }
        
        isLoadingMore = true
        let firstVisibleMessageId = viewModel.chatMessages.first?.id
        
        let fetchAction = viewModel.fromMessageListView
        ? viewModel.fetchMoreMessagesByRoomId
        : viewModel.fetchMoreMessagesBySelectedUser
        
        fetchAction { success in
            guard success, let targetId = firstVisibleMessageId else {
                self.isLoadingMore = false
                return
            }
            DispatchQueue.main.async {
                proxy.scrollTo(targetId, anchor: .top)
                self.isLoadingMore = false
            }
        }
    }
    private func loadMoreMessages2() async {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        _ = try? await viewModel.fromMessageListView
        ? viewModel.fetchMoreMessagesByRoomId2()
        : viewModel.fetchMoreMessagesBySelectedUser2()
        isLoadingMore = false
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
        if viewModel.fromMessageListView {
            navigationTitle = (viewModel.chatRoom?.isGroup ?? false)
            ? (viewModel.chatRoom?.chatName ?? "")
            : chatRoomName
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
