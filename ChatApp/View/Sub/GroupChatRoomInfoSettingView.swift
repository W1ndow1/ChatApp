//
//  GroupChatRoomInfoSettingView.swift
//  ChatApp
//
//  Created by window1 on 3/21/25.
//

import SwiftUI
import FirebaseCore
import PhotosUI

struct GroupChatRoomInfoSettingView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: NewMessageViewModel
    let selectedItems: Set<ChatUser>
    var onComplete: (Set<ChatUser>, ChatRoom) -> ()
    
    @State private var chatRoomName = ""
    @State private var chatRoomId = ""
    @State private var placeholder = ""
    @State private var selectedPickerItem: PhotosPickerItem?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                profileImageView()
                    .padding(.top, 20)
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
    
    @ViewBuilder
    func profileImageView() -> some View {
        PhotosPicker(
            selection: $selectedPickerItem,
            matching: .images,
            photoLibrary: .shared()) {
                VStack {
                    if let image = viewModel.profileImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 70))
                            .padding()
                    }
                }
                .overlay(Circle().stroke(.tint, lineWidth: 4))
            }
            .onChange(of: selectedPickerItem) { _, newItem in
                guard let newItem = newItem else { return }
                Task {
                    if let image = try? await newItem.loadTransferable(type: Data.self) {
                        viewModel.profileImage = UIImage(data: image)
                        chatRoomId = UUID().uuidString
                        viewModel.uploadChatRoomProfileImage(chatRoomId: chatRoomId)
                    }
                }
            }
    }
    
    func makeChatRoomInfo() -> ChatRoom {
        let fromId = AuthManager.shared.id ?? ""
        let participants = selectedItems.map({$0.uid}) + [fromId]
        
        return ChatRoom(chatRoomType: .group,
                        chatRoomId: self.chatRoomId,
                        chatRoomMakerId: AuthManager.shared.id ?? "",
                        chatRoomImageUrl: viewModel.profileImageURL,
                        participants: participants.sorted(by: {$0 < $1}),
                        isCustomName: true,
                        chatName: chatRoomName.count == 0
                        ? placeholder
                        : chatRoomName
        )
    }
}

#Preview {
    GroupChatRoomInfoSettingView(
        viewModel: .init(),
        selectedItems: .init(),
        onComplete: { _,_ in})
}
