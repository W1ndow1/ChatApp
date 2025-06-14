import SwiftUI
import SDWebImageSwiftUI

struct FriendListView: View {
    @StateObject private var viewModel = FriendListViewModel()
    @StateObject private var swipe = SwipeState()
    @State private var searchText = ""
    @State private var showSearchbar = false
    @State private var selectedUser: ChatUser? = nil
    @State private var selectedUserData: Set<ChatUser>?
    @State private var chatRoom = ChatRoom()
    @State private var navigateChatRoom = false

    @FocusState private var isTextFieldFocused: Bool
    @Binding var hideTabBar: Bool
    
    var body: some View {
        NavigationStack {
            VStack {
                if showSearchbar {
                    searchBar()
                }
                friendList()
                    .environmentObject(swipe)
            }
            .navigationDestination(isPresented: $navigateChatRoom) {
                if chatRoom.isNew {
                    ChatLogView(selectedUserData, chatRoom)
                        .onAppear { hideTabBar = true }
                } else {
                    ChatLogView(chatRoom: chatRoom)
                        .onAppear { hideTabBar = true }
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
    func userRow(user: ChatUser) -> some View {
        Button {
            selectedUser = user
        } label: {
            SwipeAction {
                userRowBody(user: user)
            } actions: {
                Action(tint:.yellow,
                       icon: "flag",
                       title: "즐겨찾기",
                       titleFont: .system(size: 10)) {
                    //선택시 이벤트
                    viewModel.toggleFavorite(for: user)
                }
            }
        }
        .tint(.primary)
    }
    
    @ViewBuilder
    func userRowBody(user: ChatUser) -> some View {
        HStack {
            WebImage(url: URL(string: user.profileImageURL), options: .scaleDownLargeImages)
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            
            VStack(alignment: .leading) {
                HStack {
                    Text(user.displayName)
                    if viewModel.isFavorite(user) {
                        Image(systemName: "bookmark.cicle")
                            .font(.system(size: 20))
                            .foregroundColor(Color.mint)
                    }
                }
                Text(user.email)
                    .font(.system(size: 13, weight: .light))
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 15)
    }
    
    
    @ViewBuilder
    func friendList() -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                //1.CurrentUser Section (현재유저) 상시고정
                if let currentUser = viewModel.users.first(where: { $0.uid == viewModel.currentUserId }) {
                    userRow(user: currentUser)
                    Divider()
                }
                
                //2.favoriteUser (즐겨찾기 유저)
                let favoriteUserIds = viewModel.users.filter {
                    viewModel.isFavorite($0) }
                if !favoriteUserIds.isEmpty {
                    Section {
                        ForEach(favoriteUserIds.filter { user in
                            searchText.isEmpty || user.displayName.contains(searchText) }) { user in
                                userRow(user: user)
                            }
                    } header: {
                        if !isTextFieldFocused {
                            sectionHeader(title: "즐겨찾기", count: viewModel.favoritesUsersCount)
                        }
                    }
                }
                //3.OtherUser
                Section(header: sectionHeader(title: "친구", count: viewModel.otherUsersCount)) {
                    let currentUserId = AuthManager.shared.id
                    let favoriteUserIds = Set(viewModel.users.filter { viewModel.isFavorite($0) }.map { $0.uid })
                    
                    let otherUsers = viewModel.users.filter {
                        $0.uid != currentUserId && !favoriteUserIds.contains($0.uid)
                    }
                    
                    ForEach(otherUsers.filter {
                        searchText.isEmpty ||
                        $0.displayName.contains(searchText) ||
                        $0.email.contains(searchText) }) { user in
                            userRow(user: user)
                        }
                }
            }
            .onTapGesture { self.hideKeyboard() }
            .fullScreenCover(item: $selectedUser) { user in
                ProfileView(viewModel: viewModel, user: user) { user, chatRoom in
                    navigateChatRoom.toggle()
                    selectedUserData = user
                    self.chatRoom = chatRoom
                }
            }
        }
    }
    
    @ViewBuilder
    func sectionHeader(title: String, count: Int = 0) -> some View {
        HStack {
            Text("\(title) \(count)")
                .font(.system(size: 13))
            Spacer()
        }
        .padding(.horizontal, 15)
    }
    
    
    @ViewBuilder
    func searchBar() -> some View {
        TextField(text: $searchText, label: {
            Text("검색어 입력")
        })
        .textFieldStyle(.roundedBorder)
        .focused($isTextFieldFocused)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }
    
    @ToolbarContentBuilder
    func navigationBarContent() -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Text("친구")
                .font(.system(size: 22, weight: .light))
                .padding(.trailing, 5)
        }
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 3) {
                Button {
                    withAnimation(.easeInOut(duration:0.1)){
                        showSearchbar.toggle()
                        if showSearchbar {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                isTextFieldFocused = true
                            }
                        }
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color(.label))
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
    FriendListView(hideTabBar: .constant(false))
}


