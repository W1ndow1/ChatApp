import SwiftUI
import SDWebImageSwiftUI
import FirebaseCore

struct MessageListView: View {
    @EnvironmentObject var loginModel: LoginViewModel
    @StateObject var viewModel = MessageListViewModel()
    @State var showNewMessageView = false
    @State var selectedUserData: Set<ChatUser> = []
    @State var navigationChatLogview = false

    var body: some View {
        NavigationStack {
            VStack {
                Text(viewModel.currentUser?.email ?? "")
                messageList()
                    .navigationDestination(isPresented: $navigationChatLogview, 
                                           destination: { 
                        ChatLogView(userData: selectedUserData)
                            .environmentObject(loginModel)
                    })
            }
            .onAppear() {
                viewModel.chatRooms.removeAll()
                viewModel.fetchChatRoomsListener()
            }
            .onDisappear {
                viewModel.stopListening()
            }
            .toolbar {
                navigationBarContent()
            }
        }
    }
    
    @ViewBuilder
    func messageList() -> some View {
        ScrollView {
            ForEach(viewModel.chatRooms) { num in
                VStack {
                    NavigationLink {
                        ChatLogView(userData: .none)
                    } label: {
                        HStack(spacing: 15) {
                            WebImage(url: URL(string: viewModel.profileURL ?? ""))
                            //Image(systemName: "globe")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                                .font(.system(size: 50))
                                .overlay(RoundedRectangle(cornerRadius: 44).stroke(.opacity(0.3), lineWidth: 1))
                            VStack(alignment:.leading) {
                                Text(num.chatName)
                                Text(num.lastMessage)
                                    .foregroundStyle(Color(.lightGray))
                                    .font(.system(size: 13, weight: .light))
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Text(getLastMessageTime(lastTimeStamp: num.lastMessageTimeStamp))
                                .font(.system(size: 13))
                        }
                        .padding(.horizontal, 10)
                        .tint(Color.primary)
                        Divider()
                    }
                }
                
            }
        }
        .refreshable {
            viewModel.fetchCurrentUser()
        }
    }
    
    @ToolbarContentBuilder
    func navigationBarContent() -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            HStack {
                Text("메시지")
                    .font(.system(size: 22, weight: .light))
                    .padding(.trailing, 10)
                Circle()
                    .foregroundStyle(Color.green)
                    .frame(width: 13, height: 13)
                Text("online")
                    .font(.system(size: 15, weight: .light))
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
                        .environmentObject(loginModel)
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
        .environmentObject(LoginViewModel())
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
            formatter.dateFormat = "yy-MM-dd"
            return formatter.string(from: serverDate)
        }
        
        // 2일 이상 차이
        if let days = components.day, days > 2 {
            formatter.dateFormat = "MM-dd"
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
