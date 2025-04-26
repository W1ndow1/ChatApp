import SwiftUI
import SDWebImageSwiftUI
import FirebaseCore

struct MessageListView: View {
    @StateObject private var viewModel = MessageListViewModel()
    @StateObject private var swipe = SwipeState()
    @FocusState private var isTextFieldFocused: Bool
    @State private var navigationPath = NavigationPath()
    @State private var selectedUserData: Set<ChatUser>?
    @State private var isShowSearchBar = false
    @State private var isShowingNewMsgView = false
    @State private var navigationChatLogView = false
    @State private var showLeaveAlert = false
    @State private var searchText = ""
    @State private var makeRoomInfo: ChatRoom?
    @State private var leaveRoomInfo: ChatRoom?
    @Binding var hideTabBar: Bool
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                if isShowSearchBar {
                    searchBar()
                }
                chatRoomList()
                    .environmentObject(swipe)
            }
            .navigationDestination(for: ChatRoom.self) { room in
                ChatLogView(chatRoom: room)
                    .onAppear {
                        hideTabBar = true
                    }
            }
            .navigationDestination(isPresented: $navigationChatLogView) {
                ChatLogView(selectedUserData, makeRoomInfo)
                    .onAppear {
                        hideTabBar = true
                    }
            }
            .toolbar {
                navigationBarContent()
            }
            .onAppear {
                hideTabBar = false
            }
        }
    }

    @ViewBuilder
    func chatRoomList() -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                //First section: Favorite chatRooms
                let favoriteChatRooms = viewModel.chatRooms.filter { viewModel.isFavorite($0) }
                if !favoriteChatRooms.isEmpty {
                    Section {
                        ForEach(favoriteChatRooms.filter { room in
                            (searchText.isEmpty ||
                             room.chatName.contains(searchText) ||
                             room.lastMessage.contains(searchText)) }) { room in
                                chatRoomRow(room: room)
                            }
                    } header: {
                        if !isTextFieldFocused {
                            sectionHeader()
                        }
                    }
                }
                //Normal chatRooms
                ForEach(viewModel.chatRooms.filter { room in
                    !viewModel.isFavorite(room) &&
                    (searchText.isEmpty ||
                     room.chatName.contains(searchText) ||
                     room.lastMessage.contains(searchText))}) { room in
                        chatRoomRow(room: room)
                    }
            }
            .onTapGesture { self.hideKeyboard() }
        }
    }
    
    @ViewBuilder
    func chatRoomRow(room: ChatRoom) -> some View {
        Button {
            navigationPath.append(room)
        } label: {
            SwipeAction {
                chatRoomRowBody(room: room)
            } actions: {
                Action(tint:.yellow,
                       icon: "flag",
                       title: "즐겨찾기",
                       titleFont: .system(size: 10)) {
                    viewModel.toggleFavorite(roomId: room.chatRoomId)
                }
                Action(tint: .red,
                       icon: "trash.fill",
                       title: "나가기",
                       titleFont: .system(size: 10)) {
                    leaveRoomInfo = room
                    showLeaveAlert.toggle()
                }
            }
            .alert("채팅방을 나가시겠습니까?", isPresented: $showLeaveAlert) {
                Button("확인", role: .destructive) {
                    guard let leaveRoom = leaveRoomInfo else { return }
                    viewModel.leaveChatRoom(leaveRoom)
                }
            }
        }
    }
    
    @ViewBuilder
    func chatRoomRowBody(room: ChatRoom) -> some View {
        VStack {
            HStack {
                if room.chatRoomType != .group {
                    let opponentId = room.participants.first(where: {$0 != AuthManager.shared.id }) ?? room.participants[0]
                    WebImage(url: URL(string: viewModel.usersIdInfo[opponentId]?.profileImageURL ?? ""))
                        .resizable()
                        .scaledToFill()
                        .frame(width: 51, height: 51)
                        .clipShape(Circle())
                        .overlay(RoundedRectangle(cornerRadius: 51).stroke(.opacity(0.3), lineWidth: 1))
                } else {
                    if let uid = AuthManager.shared.id {
                        let user = Array(room.participants.filter({$0 != uid }).prefix(4))
                        groupChatRoomImage(user: user)
                    }
                }
                VStack(alignment:.leading) {
                    HStack {
                        Text(room.chatName)
                        if viewModel.isFavorite(room) {
                            Image(systemName: "bookmark.circle")
                                .font(.system(size: 20))
                                .foregroundColor(Color.mint)
                            
                        }
                    }
                    let msg = room.lastMessage.count > 20
                    ? room.lastMessage.prefix(20) + "..."
                    : room.lastMessage
                    Text(msg)
                        .foregroundStyle(Color(.lightGray))
                        .font(.system(size: 13, weight: .light))
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Text(DateFormat.lastMessageTime(timeStamp: room.lastMessageTimeStamp))
                    .font(.system(size: 13))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 15)
            .tint(Color.primary)
        }
    }
    
    @ViewBuilder
    func searchBar() -> some View {
        TextField(text: $searchText, label: {
            Text("검색어 입력")
        })
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .focused($isTextFieldFocused)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }
    
    @ViewBuilder
    func sectionHeader() -> some View {
        HStack {
            Text("즐겨찾기")
                .font(.system(size: 13))
            Spacer()
        }
        .padding(.horizontal, 15)
    }
    
    @ViewBuilder
    func groupChatRoomImage(user: [String]) -> some View {
        let columns: [GridItem] = Array(repeating: .init(.flexible(minimum: 2, maximum: 4), spacing: 24), count: 2)
        LazyVGrid(columns: columns, alignment:.center, spacing: 2) {
            ForEach(user, id: \.self) { item in
                WebImage(url: URL(string: viewModel.usersIdInfo[item]?.profileImageURL ?? ""))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 25, height: 25)
                    .clipShape(Circle())
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(.opacity(0.3), lineWidth: 0.5))
            }
        }
        .frame(width: 55, height: 55)
    }
   
    @ToolbarContentBuilder
    func navigationBarContent() -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            HStack {
                Text("메시지")
                    .font(.system(size: 22, weight: .light))
                    .padding(.trailing, 5)
                Circle()
                    .foregroundStyle(Color.green)
                    .frame(width: 13, height: 13)
                Text("\(viewModel.currentUser?.displayName ?? "")")
                    .font(.system(size: 15, weight: .bold))
                Text("\(viewModel.currentUser?.email ?? "")")
                    .font(.system(size: 10, weight: .light))
            }
        }
        ToolbarItem(placement:.topBarTrailing) {
            HStack(spacing: 3) {
                Button {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isShowSearchBar.toggle()
                        if isShowSearchBar {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                isTextFieldFocused = true
                            }
                        }
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color(.label))
                }
                Button {
                    isShowingNewMsgView.toggle()
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Color(.label))
                }
                .fullScreenCover(isPresented: $isShowingNewMsgView) {
                    NewMessageView(isInChatRoom: false) { user, chatRoom in
                        self.navigationChatLogView.toggle()
                        self.selectedUserData = user
                        self.makeRoomInfo = chatRoom
                    }
                }
                
                NavigationLink {
                    SettingView()
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(Color(.label))
                }
            }
        }
    }
}

#Preview {
    MessageListView(hideTabBar: .constant(false))
}
