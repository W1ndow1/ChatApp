//
//  SideMenuView.swift
//  ChatApp
//
//  Created by window1 on 3/18/25.
//

import SwiftUI
import Firebase
import SDWebImageSwiftUI

struct SideMenuView: View {
    @Binding var isShowing: Bool
    @ObservedObject var viewModel: ChatLogViewModel
    @State private var showNewMessageView = false
    @State private var showingAlert = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            if isShowing {
                Rectangle()
                    .opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isShowing.toggle()
                    }
                HStack {
                    Spacer()
                    VStack {
                        participants()
                            .padding()
                            .scrollIndicators(.hidden)
                        Spacer()
                        leaveChatRoomButton()
                    }
                    .frame(width: 320)
                    .background(.windowBackground)
                }
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isShowing)
    }
    
    @ViewBuilder
    func participants() -> some View {
        ScrollView {
            LazyVStack(alignment:.leading, pinnedViews: [.sectionHeaders]) {
                Section {
                    let userIds = viewModel.chatRoom?.participants ?? []
                    ForEach(userIds, id: \.self) { userId in
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
            .fullScreenCover(isPresented: $showNewMessageView, content: {
                NewMessageView { users in
                    // 선택된 유저 확인해서 새로 추가되는 유저만 가져오기
                    viewModel.joinChatRoom(users: users)
                    isShowing = false
                }
            })
            Spacer()
        }
        .background(.white)
    }

    @ViewBuilder
    func leaveChatRoomButton() -> some View {
        Button {
            showingAlert = true
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("채팅방 나가기")
            }
            .font(.system(size: 15))
            .foregroundStyle(.tint)
        }
        .padding(.bottom, 20)
        .alert("채팅방을 나가시겠습니까?", isPresented: $showingAlert) {
            Button("확인", role: .destructive) {
                viewModel.leaveChatRoom()
                dismiss()
            }
        }
    }
}

#Preview {
    SideMenuView(isShowing: .constant(true), 
                 viewModel: .init(chatRoom: .init(chatRoomId:"""
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
                                                  lastMessageTimeStamp: Timestamp(date: Date()),
                                                  lastMessageSenderId: "Wv5HZZ3NMOQysA9VqEUdgdGQs713")))
}
