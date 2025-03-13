import SwiftUI
import SDWebImageSwiftUI
import FirebaseCore

struct MessageListView: View {
    @StateObject var viewModel = MessageListViewModel()
    @State private var showNewMessageView = false
    @State private var showSearchBar = false
    @State private var selectedUserData: Set<ChatUser>?
    @State private var navigationChatLogView = false
    @State private var searchText = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack {
                if showSearchBar {
                    searchBar()
                }
                messageList()
                    .navigationDestination(isPresented: $navigationChatLogView) {
                        ChatLogView(userData: selectedUserData)
                    }
            }
            .toolbar {
                navigationBarContent()
            }
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
    func messageList() -> some View {
        ScrollView {
            ForEach(viewModel.chatRooms.filter { room in
                searchText.isEmpty ||
                room.chatName.contains(searchText) ||
                room.lastMessage.contains(searchText)}) { room in
                    VStack {
                        NavigationLink {
                            ChatLogView(chatRoom: room)
                        } label: {
                            HStack(spacing: 10) {
                                if !room.isGroup {
                                    let opponentId = room.participants.first(where: {$0 != AuthManager.shared.id }) ?? room.participants[0]
                                    WebImage(url: URL(string: viewModel.usersIdInfo[opponentId]?.profileImageURL ?? ""))
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                        .overlay(RoundedRectangle(cornerRadius: 44).stroke(.opacity(0.3), lineWidth: 1))
                                } else {
                                    if let uid = AuthManager.shared.id {
                                        let user = room.participants.filter({$0 != uid })
                                        groupChatRoomImage(user: user)
                                    }
                                }
                                VStack(alignment:.leading) {
                                    Text(room.chatName)
                                    Text(room.lastMessage.prefix(20) + "......")
                                        .foregroundStyle(Color(.lightGray))
                                        .font(.system(size: 13, weight: .light))
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Text(DateFormat.lastMessageTime(timeStamp: room.lastMessageTimeStamp))
                                    .font(.system(size: 13))
                            }
                            .padding(.horizontal, 10)
                            .tint(Color.primary)
                        }
                        Divider()
                    }
                }
        }
    }
    
    @ViewBuilder
    func groupChatRoomImage(user: [String]) -> some View {
        let columns: [GridItem] = Array(repeating: .init(.flexible(minimum: 2, maximum: 4), spacing: 23), count: 2)
        LazyVGrid(columns: columns, alignment:.leading, spacing: 3) {
            ForEach(user, id: \.self) { item in
                WebImage(url: URL(string: viewModel.usersIdInfo[item]?.profileImageURL ?? ""))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 25, height: 25)
                    .clipShape(Circle())
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(.opacity(0.3), lineWidth: 1))
            }
        }
        .frame(width: 50, height: 50)
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
                        showSearchBar.toggle()
                        if showSearchBar {
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
                    showNewMessageView.toggle()
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Color(.label))
                }
                .fullScreenCover(isPresented: $showNewMessageView, onDismiss: nil, content: {
                    NewMessageView(didSelectNewUser: { user in
                        self.navigationChatLogView.toggle()
                        self.selectedUserData = user
                    })
                })
                
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
    MessageListView()
}
