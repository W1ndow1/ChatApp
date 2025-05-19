import SwiftUI
import SDWebImageSwiftUI

struct FriendListView: View {
    @StateObject private var viewModel = FriendListViewModel()
    @State private var searchText = ""
    @State private var showSearchbar = false
    @State private var selectedUser: ChatUser? = nil
    @State private var selectedUserData: Set<ChatUser>?
    @State private var chatRoom = ChatRoom()
    @State private var navigateChatRoom = false
    @State private var friendCount: Int = 0
    @FocusState private var isTextFieldFocused: Bool
    @Binding var hideTabBar: Bool
    
    var body: some View {
        NavigationStack {
            VStack {
                if showSearchbar {
                    searchBar()
                }
                friendList()
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
            .onReceive(viewModel.$users) { users in
                self.friendCount = users.filter { $0.uid != AuthManager.shared.id}.count
            }
        }
    }
    @ViewBuilder
    func userRow(user: ChatUser) -> some View {
        Button {
            selectedUser = user
        } label: {
            HStack {
                WebImage(url: URL(string: user.profileImageURL), options: .scaleDownLargeImages)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                
                VStack(alignment: .leading) {
                    Text(user.displayName)
                    Text(user.email)
                        .font(.system(size: 13, weight: .light))
                }
                Spacer()
            }
            .padding(.horizontal, 15)
        }
        .tint(.primary)
    }
    
    @ViewBuilder
    func friendList() -> some View {
        ScrollView {
            //CurrentUser Section
            if let currentUser = viewModel.users.first(where: { $0.uid == AuthManager.shared.id }) {
                userRow(user: currentUser)
                Divider()
            }
            //OtherUser
            Section(header: sectionHeader()) {
                let users = viewModel.users.filter({$0.uid != AuthManager.shared.id})
                
                ForEach(users.filter { user in
                    searchText.isEmpty ||
                    user.displayName.contains(searchText) ||
                    user.email.contains(searchText) }) { user in
                        userRow(user: user)
                        Divider()
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
    
    @ViewBuilder
    func sectionHeader() -> some View {
        HStack {
            Text("친구 \(friendCount)")
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


