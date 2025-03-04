import SwiftUI
import SDWebImageSwiftUI
import FirebaseCore

struct MessageListView: View {
    @StateObject var viewModel = MessageListViewModel()
    @State var showNewMessageView = false
    @State var selectedUserData: Set<ChatUser>?
    @State var navigationChatLogview = false

    var body: some View {
        NavigationStack {
            VStack {
                messageList()
                    .navigationDestination(isPresented: $navigationChatLogview) {
                        ChatLogView(userData: selectedUserData)
                    }
            }
            .onAppear() {
                Task {
                    guard let uid = AuthManager.shared.id else { return }
                    _ = try await viewModel.fetchCurrentUser(uid: uid)
                    viewModel.resumeListener()
                }
            }
            .onDisappear {
                viewModel.pauseListener()
            }
            .toolbar {
                navigationBarContent()
            }
        }
    }
    
    @ViewBuilder
    func messageList() -> some View {
        ScrollView {
            ForEach(viewModel.chatRooms) { room in
                VStack {
                    NavigationLink {
                        ChatLogView(chatRoom: room)
                    } label: {
                        HStack(spacing: 15) {
                            WebImage(url: URL(string: viewModel.usersInfo[room.chatRoomId]?.profileImageURL ?? ""))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                                .font(.system(size: 50))
                                .overlay(RoundedRectangle(cornerRadius: 44).stroke(.opacity(0.3), lineWidth: 1))
                            VStack(alignment:.leading) {
                                Text(room.isGroup
                                     ? room.chatName
                                     : (viewModel.usersInfo[room.chatRoomId]?.displayName ?? ""))
                                Text(room.lastMessage)
                                    .foregroundStyle(Color(.lightGray))
                                    .font(.system(size: 13, weight: .light))
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Text(getLastMessageTime(lastTimeStamp: room.lastMessageTimeStamp))
                                .font(.system(size: 13))
                        }
                        .padding(.horizontal, 10)
                        .tint(Color.primary)
                        Divider()
                    }
                }
            }
        }
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
            HStack(spacing: 5) {
                Button {
                    showNewMessageView.toggle()
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Color(.label))
                }
                .fullScreenCover(isPresented: $showNewMessageView, onDismiss: nil, content: {
                    NewMessageView(didSelectNewUser: { user in
                        self.navigationChatLogview.toggle()
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

extension MessageListView {

    func getLastMessageTime(lastTimeStamp: Timestamp) -> String {
        let serverDate = lastTimeStamp.dateValue() // 서버 시간 (UTC)
        let now = Date() // 현재 시간
        
        // 한국 시간(KST)으로 변환을 위한 캘린더 설정
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        
        // 시간 차이 계산
        let components = calendar.dateComponents([.month, .day, .hour, .minute, .second], from: serverDate, to: now)
        
        // DateFormatter 설정 (필요할 때만 사용)
        let formatter = DateFormatter()
        formatter.timeZone = calendar.timeZone
        
        // 1년 이상 차이
        if let months = components.month, months >= 12 {
            formatter.dateFormat = "yy년MM월dd일"
            return formatter.string(from: serverDate)
        }
        
        // 2일 이상 차이
        if let days = components.day, days > 1 {
            formatter.dateFormat = "M월dd일"
            return formatter.string(from: serverDate)
        }
        
        // 어제
        if let days = components.day, days == 1 {
            return "어제"
        }
        
        // 오늘 (24시간 이내)
        if let hours = components.hour, hours >= 1 {
            return "\(hours)시간 전"
        }
        
        // 1시간 이내
        if let minutes = components.minute, minutes >= 1 {
            return "\(minutes)분 전"
        }
        
        // 1분 미만
        return "방금 전"
    }
}
