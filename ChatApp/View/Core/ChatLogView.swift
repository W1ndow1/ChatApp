//
//  ChatLogView.swift
//  ChatApp
//
//  Created by window1 on 2/12/25.
//

import SwiftUI
import SDWebImageSwiftUI

struct ChatLogView: View {
    @ObservedObject var viewModel: ChatLogViewModel
    @State var navigationTitle = ""
    @State var enterButtonText = "#"
    @State var loginUserID = AuthManager().id
    @State var chatRoom: ChatRooms?
    
    let userData: Set<ChatUser>?
    
    //새 채팅방 생성시
    init(userData: Set<ChatUser>?) {
        self.userData = userData
        self.viewModel = .init(userData: userData)
    }
    
    //채팅방 목록으로 들어온 경우
    init(chatRoom: ChatRooms) {
        self.userData = .none
        self.chatRoom = chatRoom
        viewModel = .init(chatRoom: chatRoom)
    }
    
    var body: some View {
        ZStack {
            chatBubbleRow()
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    titleLengthCheck()
                    if !viewModel.fromMessageListView {
                        viewModel.fetchUserInfo()
                        viewModel.fetchMessagesBySelectedUser()
                    } else {
                        viewModel.fetchMessagesByRoomId()
                    }
                }
                .onDisappear {
                    viewModel.stopListening()
                }
        }
    }
    
    @ViewBuilder
    private func chatBubbleRow() -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                ForEach(viewModel.chatMessages) { msg in
                    VStack {
                        HStack {
                            if msg.senderId != loginUserID {
                                HStack(alignment: .top) {
                                    if msg.isFirstInTimeGroup ?? false {
                                        WebImage(url: URL(string: viewModel.usersInfo[msg.senderId]?.profileImageURL ?? ""))
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
                                            Text(viewModel.usersInfo[msg.senderId]?.displayName ?? "")
                                                .font(.system(size: 10, weight: .ultraLight))
                                        }
                                        HStack(alignment: .bottom) {
                                            Text(msg.text)
                                                .padding(8)
                                                .background(Color.white)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .frame(minWidth: 30, alignment: .leading)
                                                .lineLimit(nil)
                                                .multilineTextAlignment(.leading)
                                                .id(msg.id)
                                            if msg.isFirstInTimeGroup ?? false {
                                                Text(convertToTimeStamp(date: msg.timeStamp.dateValue()))
                                                    .font(.system(size: 10, weight: .ultraLight))
                                            }
                                            Spacer()
                                        }
                                    }
                                }
                                Spacer()
                            } else {
                                Spacer()
                                HStack(alignment: .bottom) {
                                    Spacer()
                                    if msg.isFirstInTimeGroup ?? false {
                                        Text(convertToTimeStamp(date: msg.timeStamp.dateValue()))
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
                                        .id(msg.id)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    HStack { Spacer() }
                }
            }
            .onTapGesture { hideKeyboard() }
            .defaultScrollAnchor(.bottom)
            .background(Color(white: 0.3, opacity: 0.1))
            .safeAreaInset(edge: .bottom, content: viewBottom)
            .onChange(of: viewModel.chatMessages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo(viewModel.chatMessages.last?.id, anchor: .bottom)
                }
            }
        }
    }
    
    @ViewBuilder
    private func viewBottom() -> some View {
        HStack {
            Button{
                
            } label: {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundStyle(Color.primary)
            }
            TextField("메시지", text: $viewModel.chatText, axis: .vertical)
                .foregroundStyle(Color.primary)
                .onChange(of: viewModel.chatText, { old, new in
                    enterButtonText = viewModel.chatText.count > 0 ? "⇧" : "#"
                })
            Button {
                if !viewModel.chatText.isEmpty {
                    if viewModel.fromMessageListView {
                        viewModel.sendMessageByRoomId()
                    } else {
                        viewModel.sendMessage()
                    }
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .frame(width: 30, height: 30)
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
    ChatLogView(userData: .none)
    
}

extension ChatLogView {
    func formatData(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년, MM월 dd일"
        return formatter.string(from: date)
    }
    
    func convertToTimeStamp(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a hh:mm"
        return formatter.string(from: date)
    }
    
    func titleLengthCheck() {
        if viewModel.fromMessageListView {
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
