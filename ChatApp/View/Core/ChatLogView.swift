//
//  ChatLogView.swift
//  ChatApp
//
//  Created by window1 on 2/12/25.
//

import SwiftUI

struct ChatLogView: View {
    @ObservedObject var viewModel: ChatLogViewModel
    @State var navigationTitle = ""
    @State var enterButtonText = "#"
    @State var loginUserID = AuthManager().id
    @State var fromMessageListView = false
    @State var chatRoom: ChatRooms?
    
    let userData: Set<ChatUser>?
    
    //새 채팅방 생성시
    init(userData: Set<ChatUser>?) {
        self.userData = userData
        self.viewModel = .init(userData: userData)
        fromMessageListView = false
    }
    
    //채팅방 목록으로 들어온 경우
    init(chatRoomId roomId: String, chatRoom roomInfo: ChatRooms) {
        self.userData = .none
        chatRoom = roomInfo
        viewModel = .init(chatRoomId: roomId)
        fromMessageListView = true
    }

    var body: some View {
        ZStack {
            chatBubbleRow()
                .navigationTitle("\(navigationTitle)")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                titleLengthCheck()
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
                ForEach(viewModel.chatMessages) { num in
                    HStack {
                        if num.senderId != loginUserID {
                            HStack {
                                Text(num.text)
                                    .padding(8)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .frame(minWidth: 30 ,maxWidth: 250, alignment: .leading)
                                    .lineLimit(nil)
                                    .multilineTextAlignment(.leading)
                                    .id(num.id)
                                
                            }
                            Spacer()
                        } else {
                            Spacer()
                            HStack {
                                Text(num.text)
                                    .padding(8)
                                    .foregroundStyle(Color.white)
                                    .background(Color.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .frame(minWidth: 30 ,maxWidth: 250, alignment: .trailing)
                                    .lineLimit(nil)
                                    .multilineTextAlignment(.leading)
                                    .id(num.id)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
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
                    if fromMessageListView {
                        viewModel.sendMessageByRoomId()
                    }else {
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
    func titleLengthCheck() {
        guard let userData = userData else { return }
        if userData.count < 4 {
            navigationTitle = userData.map({ $0.displayName }).joined(separator: ", ")
        } else {
            navigationTitle = userData.prefix(3).map({ $0.displayName }).joined(separator: ", ") + "..."
        }
    }
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
