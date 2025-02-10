import SwiftUI

struct MessageListView: View {
    @EnvironmentObject var viewModel: LoginViewModel
    @StateObject var model = MessageViewModel()
    @State var newShowNewMessageScreen = false
    
    var body: some View {
        NavigationStack {
            Text(model.currentUser?.email ?? "")
            ScrollView {
                ForEach(0..<20, id: \.self) { num in
                    HStack(spacing: 15) {
                        Group {
                            if let image = model.profileImage {
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
                        VStack(alignment: .leading){
                            Text("사용자 이름")
                            Text("보낸메시지 안녕하세요 가나다라마바사123456 ABCDabcd")
                                .foregroundStyle(Color(.lightGray))
                                .font(.system(size: 15, weight: .light))
                        }
                        Spacer()
                        Text("1시간")
                    }
                    .padding(.horizontal, 10)
                    Divider()
                }
            }
            .toolbar {
                navigationBarContent()
            }
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
                    newShowNewMessageScreen.toggle()
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Color(.label))
                }
                .fullScreenCover(isPresented: $newShowNewMessageScreen, onDismiss: nil, content: {
                    NewMessageView()
                })
                
                NavigationLink {
                    SettingView()
                        .environmentObject(viewModel)
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
