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
    @State var chatRoomName = ""
    @State private var isLoadingMore = false
    
    let userData: Set<ChatUser>?
    
    //새 채팅방 생성으로 들어온 경우
    init(userData: Set<ChatUser>?) {
        self.userData = userData
        self.viewModel = .init(userData: userData)
    }
    
    //채팅방 목록으로 들어온 경우
    init(chatRoom: ChatRooms, chatRoomName: String) {
        self.userData = .none
        self.chatRoom = chatRoom
        self.chatRoomName = chatRoomName
        viewModel = .init(chatRoom: chatRoom)
    }
    
    var body: some View {
        ZStack {
            chatBubbleRow()
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    if viewModel.fromMessageListView {
                        viewModel.fetchInitialMessagesByRoomId()
                        viewModel.startRealTimeListener()
                    }
                    navigationTitleLengthCheck()
                    /*
                    if viewModel.fromMessageListView {
                        viewModel.fetchRecentMessageByRoomId()
                    } else {
                        viewModel.fetchRecentMessagesBySelectedUser()
                    }
                    navigationTitleLengthCheck()
                     */
                }
                .onDisappear {
                    viewModel.stopListening()
                }
        }
    }
    
    @ViewBuilder
    private func chatSection(msg: ChatMessages) -> some View {
        if msg.isFirstInDayGroup ?? false {
            HStack {
                Text(formatDataToYear(msg.timeStamp.dateValue()))
                    .padding(8)
                    .font(.system(size: 12, weight: .light))
                    .background(Color.gray.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.vertical, 20)
            .onTapGesture {
                print("🪛 Tab Calendar")
            }
        }
    }
    
    @ViewBuilder
    private func chatBubbleRow() -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack {
                    ProgressView()
                        .opacity(isLoadingMore ? 1 : 0)
                        .onAppear {
                            //loadMoreMessages(proxy)
                            /*
                            Task { @MainActor in
                               await loadMoreMessages2(proxy)
                            }
                             */
                        }
                    ForEach(viewModel.chatMessages) { msg in
                        Section(header: chatSection(msg: msg)) {
                            HStack {
                                if msg.senderId != loginUserID {
                                    otherMessage(msg: msg)
                                } else {
                                    myMessage(msg: msg)
                                }
                            }
                            .id(msg.id)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                        }
                    }
                }
            }
            .defaultScrollAnchor(.bottom)
            .background(Color(white: 0.3, opacity: 0.1))
            .safeAreaInset(edge: .bottom) {
                viewBottom(proxy: proxy)
            }
            .onTapGesture { hideKeyboard() }
        }
    }
    
    @ViewBuilder
    private func otherMessage(msg: ChatMessages) -> some View {
        HStack(alignment: .top) {
            if (msg.senderId != loginUserID) && (msg.isFirstInTimeGroup ?? false) {
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
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(minWidth: 30, alignment: .leading)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                    if msg.isFirstInTimeGroup ?? false {
                        Text(formatDataToTime(msg.timeStamp.dateValue()))
                            .font(.system(size: 10, weight: .light))
                    }
                    Spacer()
                }
            }
        }
        Spacer()
    }
    
    @ViewBuilder
    private func myMessage(msg: ChatMessages) -> some View {
        Spacer()
        HStack(alignment: .bottom) {
            Spacer()
            if msg.isFirstInTimeGroup ?? false {
                Text(formatDataToTime(msg.timeStamp.dateValue()))
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
        }
    }

    
    @ViewBuilder
    private func viewBottom(proxy: ScrollViewProxy) -> some View {
        HStack {
            Button{
                
            } label: {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundStyle(Color.primary)
            }
            TextField("메시지", text: $viewModel.chatText, axis: .vertical)
                .foregroundStyle(Color.primary)
                .padding(8)
                .overlay(content: {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.primary, lineWidth: 0.8)
                })
                .onChange(of: viewModel.chatText, { old, new in
                    enterButtonText = viewModel.chatText.count > 0 ? "⇧" : "#"
                })
            Button {
                if !viewModel.chatText.isEmpty {
                    let sendAction: () = viewModel.fromMessageListView 
                    ? viewModel.sendMessageByRoomId()
                    : viewModel.sendMessage()
                    sendAction
                    
                    let lastMsgId = viewModel.chatMessages.last?.id
                    DispatchQueue.main.async {
                        proxy.scrollTo(lastMsgId, anchor: .bottom)
                    }
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .frame(width: 40, height: 40)
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
    ChatLogView(chatRoom: ChatRooms(
        chatRoomId: "UyZOQtY9occyvmxpP82jr7QdEP12_WDznGLHspLevJ0kgC9m783bUtWB3_Wv5HZZ3NMOQysA9VqEUdgdGQs713_uBzmBwnRmdbkCFoBls9DHa4uC8j2",
        participants: ["UyZOQtY9occyvmxpP82jr7QdEP12","WDznGLHspLevJ0kgC9m783bUtWB3","Wv5HZZ3NMOQysA9VqEUdgdGQs713","uBzmBwnRmdbkCFoBls9DHa4uC8j2"],
        lastMessageTimeStamp: .init(date: Date())), chatRoomName: "홍길동")
    
}

extension ChatLogView {
   
    private func loadMoreMessages(_ proxy: ScrollViewProxy) {
        guard !isLoadingMore else { return }
        
        isLoadingMore = true
        let firstVisibleMessageId = viewModel.chatMessages.first?.id
        
        let fetchAction = viewModel.fromMessageListView
        ? viewModel.fetchMoreMessagesByRoomId
        : viewModel.fetchMoreMessagesBySelectedUser
        
        fetchAction { success in
            guard success, let targetId = firstVisibleMessageId else {
                self.isLoadingMore = false
                return
            }
            DispatchQueue.main.async {
                proxy.scrollTo(targetId, anchor: .top)
                self.isLoadingMore = false
            }
        }
    }
    @MainActor
    private func loadMoreMessages2(_ proxy: ScrollViewProxy) async {
        guard !isLoadingMore else { return }
        
        isLoadingMore = true
        let firstVisibleMessagesId = viewModel.chatMessages.first?.id
        
        let success = try? await viewModel.fromMessageListView
        ? viewModel.fetchMoreMessagesByRoomId2()
        : viewModel.fetchMoreMessagesBySelectedUser2()
        
        if success == true, let targetId = firstVisibleMessagesId {
            proxy.scrollTo(targetId, anchor: .top)
        }
        isLoadingMore = false
    }
    
    func formatDataToYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일"
        return formatter.string(from: date)
    }
    
    func formatDataToTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter.string(from: date)
    }
    
    func formatDateToString(_ date: Date, dateFormat: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = dateFormat
        return formatter.string(from: date)
    }
    
    func navigationTitleLengthCheck() {
        if viewModel.fromMessageListView {
            navigationTitle = (chatRoom?.isGroup ?? false)
            ? (chatRoom?.chatName ?? "")
            : chatRoomName
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
