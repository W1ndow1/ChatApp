//
//  GroupChatRoomInfoSettingView.swift
//  ChatApp
//
//  Created by window1 on 3/21/25.
//

import SwiftUI
import FirebaseCore

struct GroupChatRoomInfoSettingView: View {
    @Environment(\.dismiss) var dismiss
    @State private var chatRoomName = ""
    @State private var placeholder = ""
    
    let selectedItems: Set<ChatUser>
    var onComplete: (Set<ChatUser>, ChatRoom) -> ()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                Image(systemName: "globe")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                VStack {
                    HStack {
                        TextField(placeholder, text: $chatRoomName)
                            .characterLimit(limit: 50, text: $chatRoomName)
                        Spacer()
                        Text("\(chatRoomName.count)/50")
                            .font(.system(size: 15))
                            .foregroundStyle(.opacity(0.3))
                    }
                    .padding(.horizontal, 15)
                    
                    Rectangle()
                        .foregroundStyle(Color.black)
                        .frame(width: 365, height: 1)
                        .padding(.bottom, 15)
                    
                    Text("""
                         채팅시작 전, 내가 설정한 그룹 채팅방의 사진과 이름은 다른 모든
                         대화상대에게도 동일하게 보입니다.
                         """)
                    .font(.system(size: 14.5, weight: .thin))
                    .foregroundStyle(Color.gray)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 10)
                    
                }
            }
        }
        .navigationTitle("그룹채팅방 정보 설정")
        .navigationBarBackButtonHidden()
        .onAppear {
            let placeholder = selectedItems.map({$0.displayName}).joined(separator: ", ")
            self.placeholder = placeholder
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onComplete(selectedItems, makeChatRoomInfo())
                } label: {
                    Text("확인")
                }
            }
        }
    }
    
    func makeChatRoomInfo() -> ChatRoom {
        let fromId = AuthManager.shared.id ?? ""
        let participants = selectedItems.map({$0.uid}) + [fromId]
        
        return ChatRoom(chatRoomType: .group,
                        chatRoomId: UUID().uuidString,
                        chatRoomMakerId: AuthManager.shared.id ?? "",
                        participants: participants.sorted(by: {$0 < $1}),
                        chatName: chatRoomName.count == 0
                        ? placeholder
                        : chatRoomName
        )
    }
}

#Preview {
    GroupChatRoomInfoSettingView(selectedItems: .init(), onComplete: { _,_ in})
}
