import SwiftUI
import SDWebImageSwiftUI

struct MessageListView: View {
    @EnvironmentObject var loginModel: LoginViewModel
    @StateObject var messageModel = MessageListViewModel()
    @State var showNewMessageView = false
    @State var selectedUserData: Set<ChatUser> = []
    @State var navigationChatLogview = false

    
    var body: some View {
        NavigationStack {
            VStack {
                Text(messageModel.currentUser?.email ?? "")
                messageList()
                    .navigationDestination(isPresented: $navigationChatLogview, 
                                           destination: { ChatLogView(userData: selectedUserData) })
            }
            .toolbar {
                navigationBarContent()
            }
        }
    }
    
    @ViewBuilder
    func messageList() -> some View {
        ScrollView {
            ForEach(0..<20, id: \.self) { num in
                VStack {
                    NavigationLink {
                        Text("Destination")
                    } label: {
                        HStack(spacing: 15) {
                            Group {
                                if let image = messageModel.profileImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "globe")
                                }
                            }
                            .font(.system(size: 50))
                            .overlay(RoundedRectangle(cornerRadius: 44).stroke(.opacity(0.3), lineWidth: 1))
                            VStack(alignment:.leading) {
                                Text(messageModel.currentUser?.displayName ?? "오동나무")
                                Text("보낸메시지 안녕하세요 123123")
                                    .foregroundStyle(Color(.lightGray))
                                    .font(.system(size: 15, weight: .light))
                            }
                            Spacer()
                            Text("1시간")
                        }
                        .padding(.horizontal, 10)
                        .tint(Color.primary)
                        Divider()
                    }
                }
            }
        }
        .refreshable {
            messageModel.fetchCurrentUser()
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
