//
//  NewMessageView.swift
//  ChatApp
//
//  Created by window1 on 2/8/25.
//

import SwiftUI
import SDWebImageSwiftUI
import Firebase

struct NewMessageView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var viewModel = NewMessageViewModel()
    @State private var searchText = ""
    @State private var selectedItems: Set<ChatUser> = []
    @State private var navigateToSettingView = false
    @State private var showSheet = false
 
    var isInChatRoom: Bool
    var chatRoomInfo: (Set<ChatUser>, ChatRoom) -> ()
    
    var body: some View {
        NavigationStack {
            Group {
                TextField("🔎 검색", text: $searchText)
                    .padding(.horizontal, 10)
                    .frame(height: 40)
                    .border(Color.gray, width: 0.5)
            }
            .padding(10)
            
            ScrollView{
                if !isInChatRoom {
                    if let existRooms = viewModel.existChatRooms, existRooms.count > 0 {
                        Button {
                            showSheet.toggle()
                        } label: {
                            Text("선택한 사용자가 참여하고 있는 채팅방 : \(existRooms.count)개")
                                .font(.system(size: 15, weight: .thin))
                            
                        }
                        .sheet(isPresented: $showSheet) {
                            sheetView(existRooms)
                                .presentationDetents([.height(300)])
                                .presentationDragIndicator(.visible)
                                .presentationCornerRadius(20)
                        }
                    }
                } else {
                    EmptyView()
                }

                ForEach(viewModel.users.filter { user in
                    searchText.isEmpty ||
                    user.displayName.contains(searchText) ||
                    user.email.contains(searchText)}) { data in
                        NewMessagesViewRow(user: data, selectedItems: $selectedItems, viewModel: viewModel)
                }
            }
            .navigationTitle("대화상대 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button{
                        dismiss()
                    } label: {
                        Text("취소")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        //새로 채팅방을 만든 경우
                        if !isInChatRoom && selectedItems.count > 1 {
                            navigateToSettingView = true
                        //기존 채팅방에서 초대한 경우
                        } else {
                            chatRoomInfo(selectedItems, makeChatRoomInfo())
                            dismiss()
                        }
                    } label: {
                        Text("확인")
                    }
                    .disabled(selectedItems.isEmpty)
                }
            }
            .navigationDestination(isPresented: $navigateToSettingView) {
                GroupChatRoomInfoSettingView(viewModel: viewModel, selectedItems: selectedItems) { selectedItems, chatRoom in
                    chatRoomInfo(selectedItems, chatRoom)
                    dismiss()
                }
            }
        }
    }
    
    @ViewBuilder
    func sheetView(_ existRooms: [ChatRoom]) -> some View {
        ScrollView {
            ForEach(existRooms) { room in
                VStack{
                    HStack{
                        Circle()
                            .frame(width: 40, height: 40)
                            .foregroundStyle(Color.customAlert)
                        Button {
                            chatRoomInfo(selectedItems, room)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading) {
                                Text(room.chatName)
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundStyle(Color.blackWhite)
                                Text(room.lastMessage)
                                    .font(.system(size: 13, weight: .light))
                                    .foregroundStyle(.gray)
                            }
                        }
                        Spacer()
                    }
                    Divider()
                }
                .padding(.vertical, 5)
            }
        }
        .scrollIndicators(.hidden)
        .padding(.top, 20)
        .padding(.horizontal, 20)
    }
    
    func makeChatRoomInfo() -> ChatRoom {
        let fromId = AuthManager.shared.id ?? ""
        let participants = selectedItems.map({$0.uid}) + [fromId]
        let chatName = selectedItems.map{$0.displayName}.joined(separator: ",")
        
        if let existChatRooms = viewModel.existChatRooms?.first {
            return existChatRooms
        } else {
            return ChatRoom(chatRoomType: (participants.count > 2 ? .group : .direct),
                            chatRoomId: UUID().uuidString,
                            chatRoomMakerId: fromId,
                            participants: participants.sorted(by: {$0 < $1}),
                            chatName: chatName
            )
        }
    }
}


#Preview {
    NewMessageView(isInChatRoom: false) { _, _ in }
}


struct NewMessagesViewRow: View {
    @State var checkedRow = false
    let user: ChatUser
    @Binding var selectedItems: Set<ChatUser>
    @ObservedObject var viewModel: NewMessageViewModel
    
    var body: some View {
        HStack {
            WebImage(url: URL(string: user.profileImageURL))
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            VStack(alignment: .leading) {
                Text(user.displayName)
                Text(user.email)
                    .font(.system(size: 13, weight: .light))
            }
            Spacer()
            Button {
                checkedRow.toggle()
                if checkedRow {
                    selectedItems.insert(user)
                } else {
                    selectedItems.remove(user)
                }
                
                Task {
                    print("\(selectedItems.map{$0.uid})")
                    if selectedItems.count > 0 {
                        await viewModel.collectionChatRooms(makeChatRoomParticipants(selectedItems))
                    }
                }
                
            }label: {
                Image(systemName: checkedRow ? "checkmark.circle.fill" : "checkmark.circle" )
                    .font(.system(size: 20, weight: .light))
                    .tint(.primary)
            }
        }
        .padding(.horizontal, 15)
        Divider()
        
    }
    
    func makeChatRoomParticipants(_ selectedItems: Set<ChatUser>) -> [String] {
        guard let uid = AuthManager.shared.id else { return [] }
        var users = selectedItems.map({$0.uid}).sorted()
        users.append(uid)
        return users
    }
    
}
