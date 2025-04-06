//
//  SideMenuView.swift
//  ChatApp
//
//  Created by window1 on 3/18/25.
//

import SwiftUI
import Firebase
import SDWebImageSwiftUI

struct ChatRoomSideMenuView: View {
    @ObservedObject var viewModel: ChatLogViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showNewMessageView = false
    @State private var leaveAlert = false
    @State private var validateAlert = false
    @State private var isShowSettingView = false
    @Binding var isShowSelectUserView: Bool
    
    var body: some View {
        ZStack {
            if isShowSelectUserView {
                Rectangle()
                    .opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isShowSelectUserView.toggle()
                    }
                HStack {
                    Spacer()
                    VStack {
                        participants()
                            .padding()
                            .scrollIndicators(.hidden)
                        Spacer()
                        bottomView()
                            
                    }
                    .frame(width: 320)
                    .background(.windowBackground)
                }
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isShowSelectUserView)
        .customAlert(title: viewModel.chatRoom?.chatName, message: "채팅방을 나가시겠습니까?", isPresented: $leaveAlert, actions: [
            AlertAction(title: "취소", role: .destructive){},
            AlertAction(title: "확인", role: .none){
                viewModel.leaveChatRoom()
                dismiss()
            }
        ])
        .customAlert(title: "추가실패", message: "이미 채팅방에 있는 인원입니다.", isPresented: $validateAlert, actions: [AlertAction(title: "확인", role: .none, action: {})])
    }
    
    @ViewBuilder
    func bottomView() -> some View {
        HStack(spacing: 25) {
            leaveChatRoomButton()
            Spacer()
            Group {
                Button {
                    
                }label: {
                    Image(systemName: "bell.fill")
                }
                Button {
                    
                }label: {
                    Image(systemName: "star.fill")
                }
                Button {
                    isShowSettingView.toggle()
                }label: {
                    Image(systemName: "gearshape")
                }
                .fullScreenCover(isPresented: $isShowSettingView) {
                    ChatRoomSettingView()
                }
            }
            .font(.system(size: 18, weight: .bold))
        }
        .padding(.vertical, 15)
        .padding(.leading, 10)
        .padding(.trailing, 20)
        .background(Color.gray.opacity(0.1))
    }
    
    @ViewBuilder
    func participants() -> some View {
        ScrollView {
            LazyVStack(alignment:.leading, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(viewModel.chatRoom?.participants ?? [], id: \.self) { userId in
                        let userInfo = viewModel.usersInfo?[userId]
                        HStack(spacing: 10) {
                            WebImage(url: URL(string: userInfo?.profileImageURL ?? ""))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                                .overlay(RoundedRectangle(cornerRadius: 40).stroke(.opacity(0.3), lineWidth: 1))
                            Text(userInfo?.displayName ?? "")
                                .font(.system(size: 14, weight: .light))
                        }
                    }
                    Divider()
                } header: {
                    sectionHeader()
                }
            }
        }
    }
    
    @ViewBuilder
    func sectionHeader() -> some View {
        HStack {
            Button {
                showNewMessageView.toggle()
            } label: {
                HStack(spacing: 3) {
                    Text("대화상대")
                        .font(.system(size: 18, weight: .light))
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 15, weight: .medium))
                }
                .tint(.primary)
                .padding(.bottom, 5)
            }
            .disabled(viewModel.chatRoom?.chatRoomType == .selfChat)
            .fullScreenCover(isPresented: $showNewMessageView) {
                //기존 채팅방 정보 보내기
                NewMessageView(isInChatRoom: true) { users, chatRoom in
                    let addUsers = viewModel.validateChatRoomMembers(users: users)
                    if addUsers.count > 0 {
                        viewModel.joinChatRoom(users: addUsers)
                        isShowSelectUserView = false
                    } else {
                        validateAlert.toggle()
                    }
                }
            }
            
            /*
             .alert("이미 채팅방에 있는 인원입니다.", isPresented: $validateAlert) {
                Button("확인", role: .none) { }
            }
             */
            Spacer()
        }
        .background(Color.clear)
    }

    @ViewBuilder
    func leaveChatRoomButton() -> some View {
        Button {
            leaveAlert = true
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
            }
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.tint)
        }
        /*
        .alert("채팅방을 나가시겠습니까?", isPresented: $leaveAlert) {
            Button("확인", role: .destructive) {
                viewModel.leaveChatRoom()
                dismiss()
            }
        }
         */
        
    }
}


#Preview {
    ChatRoomSideMenuView(viewModel: .init(chatRoom: ChatRoom(
        chatRoomType: ChatRoomType.group,
        chatRoomId: """
                    UyZOQtY9occyvmxpP82jr7QdEP12_
                    WDznGLHspLevJ0kgC9m783bUtWB3_
                    Wv5HZZ3NMOQysA9VqEUdgdGQs713_
                    qZHV0Ds2YMWgZ1vLeNl1fHL5C2C3_
                    uBzmBwnRmdbkCFoBls9DHa4uC8j2
                    """,
        chatRoomMakerId: "Wv5HZZ3NMOQysA9VqEUdgdGQs713",
        participants: ["UyZOQtY9occyvmxpP82jr7QdEP12",
                      "WDznGLHspLevJ0kgC9m783bUtWB3",
                      "Wv5HZZ3NMOQysA9VqEUdgdGQs713",
                      "qZHV0Ds2YMWgZ1vLeNl1fHL5C2C3",
                      "uBzmBwnRmdbkCFoBls9DHa4uC8j2"],
        isCustomName: true,
        chatName: "점심모임🍎🍙🥟🥗🥪",
        lastMessage: "Last test message",
        lastMessageTimeStamp: Timestamp(date: Date()),
        lastMessageSenderId: "Wv5HZZ3NMOQysA9VqEUdgdGQs713")), isShowSelectUserView: .constant(true))
}
