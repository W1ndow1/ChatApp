//
//  ProfileView.swift
//  ChatApp
//
//  Created by window1 on 3/12/25.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: FriendListViewModel
    
    let user: ChatUser
    var startChatting: (Set<ChatUser>, ChatRoom) -> ()?
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                WebImage(url: URL(string: user.profileImageURL))
                    .resizable()
                    .scaledToFit()
                    .frame(height: 140)
                    .clipShape(Circle())
                    .overlay { Circle().stroke(.tint, lineWidth: 4) }
                Text(user.displayName)
                    .font(.title)
                    .bold()
                
                Text(user.email)
                    .foregroundStyle(.secondary)
                HStack {
                    Button {
                        startChatting(makeUserArray(user: user), makeChatRoomInfo())
                        dismiss()
                    } label: {
                        Text(AuthManager.shared.id == user.uid ? "나와 채팅하기" : "채팅하기" )
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.tint)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(10)
                }
                Color.clear
                    .frame(height: 50)
            }
            .toolbar {
                navigationBarContent()
            }
        }
        .onAppear() {
            Task {
                await viewModel.collectionChatRooms([user.uid] + [AuthManager.shared.id ?? ""])
            }
        }
    }

    @ToolbarContentBuilder
    func navigationBarContent() -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button{
                dismiss()
            }label: {
                Text("✕")
                    .font(.system(size: 20))
            }
        }
    }
    
    func makeUserArray(user: ChatUser) -> Set<ChatUser> {
        var users = Set<ChatUser>()
        users.insert(user)
        return users
    }
    
    func makeChatRoomInfo() -> ChatRoom {
        let fromId = AuthManager.shared.id ?? ""
        let participants = [user.uid] + [fromId]
        let chatName = user.displayName

        if let existChatRooms = viewModel.existChatRooms.first {
            return existChatRooms
        } else {
            return ChatRoom(chatRoomType: (fromId == user.id ? .selfChat : .direct),
                            chatRoomId: UUID().uuidString,
                            chatRoomMakerId: fromId,
                            participants: participants.sorted(by: {$0 < $1}),
                            chatName: chatName
            )
        }
    }
}

#Preview {
    ProfileView(viewModel: .init(), 
    user: ChatUser(uid: "UyZOQtY9occyvmxpP82jr7QdEP12",
                   email:"Doserack10@gmail.com",
                   profileImageURL:
                    """
                    https://firebasestorage.googleapis
                    .com:443/v0/b/swiftui-firebase-chetapp
                    .firebasestorage.app/o/images%2FUyZOQtY9occyvmxpP82jr7QdEP12
                    .jpeg?alt=media&token=96f72d55-efb5-42d6-94d1-5c916e68227e
                    """,
                   displayName: "홍길동"
                  ), startChatting: { _,_  in }
    )
}
