//
//  ChatRoomSettingView.swift
//  ChatApp
//
//  Created by window1 on 3/27/25.
//

import SwiftUI
import FirebaseCore

struct ChatRoomSettingView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ChatLogViewModel
    @StateObject var settingVM = ChatRoomSettingViewModel()
    @State private var chatRoomName: String = ""
    
    
    var body: some View {
        NavigationStack {
            ScrollView {
                /*
                 (1)채팅방 이미지 설정
                 (2)채팅방 이름 설정 => 사용자마다 어떻게 보이게 할것인지????
                 (3)채팅방 배경화면 => 채팅방마다 배경을 어떻게 할것인가? 로컬에 저장해 놓는다? 서버에 올릴 필요는 없어보이니까? 그리고 이미지로 설정할것인지? 아니면 샘프
                 (4)채팅방 입력설정 =>
                 (5)채팅방 내용 내보내기 => 텍스트 파일로 내보내기
                 (6)채팅방 나가기 => 기존에 있는거 가져오면됨
                 (7)초대금지 => 이건 서버에 남겨야 가능함
                 */
                
                //채팅방 사용자
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .frame(width:50, height: 50)
                            .foregroundStyle(Color.accentColor.opacity(0.8))
                        Image(systemName: "person.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(Color(white: 1.0, opacity: 0.75))
                        //본인 사진이 있는 경우 변경하기
                    }
                    
                    Text("홍길동")
                        .font(.system(size: 15, weight: .light))
                    
                    Spacer()
                    Button {
                        print("1234")
                    } label: {
                        Text("수정하기")
                            .padding(10)
                            .foregroundStyle(.blackWhite)
                            .font(.system(size: 11, weight: .medium))
                            .overlay(content: {
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.black, lineWidth: 1)
                            })
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 15)
                Divider()
                
                //채팅방 이름 변경
                VStack(alignment: .leading) {
                    Text("채팅방 이름")
                        .font(.system(size: 15, weight: .light))
                    TextField("채팅방 이름", text: $chatRoomName)
                        .font(.system(size: 15, weight: .light))
                }
                .padding(15)
                
                //채팅방 배경화면 설정
                HStack {
                    VStack(alignment: .center) {
                        Text("현재 채팅방 배경화면")
                            .font(.system(size: 15, weight: .light))
                    }
                    ColorPicker("", selection: $settingVM.selectColor)
                        .onChange(of: settingVM.selectColor) { _, value in
                            if let hex = value.toHexCode() {
                                print(("Hex Code: \(hex)"))
                                guard let id = AuthManager.shared.id,
                                      let roomId = viewModel.chatRoom?.id
                                else { return }
                                Task {
                                    await settingVM.updateChatRoomBackGroundColor(userId: id, chatRoomId: roomId, color: hex)
                                }
                            }
                        }
                }
                .padding(15)
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Text("채팅방 설정")
                        .font(.system(size: 20, weight: .thin))
                }
                 
                
                ToolbarItem(placement:.topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("나가기")
                            .font(.system(size: 15, weight: .medium))
                    }
                }
            }
            .onAppear() {
                guard let id = AuthManager.shared.id,
                      let roomId = viewModel.chatRoom?.id else { return }
                Task {
                    await settingVM.fetchChatRoomBackGroundColor(userId: id, chatRoomId: roomId)
                }
                           }
            .overlay(content: {
                AppErrorView()
            })
        }
    }
}

#Preview {
    ChatRoomSettingView(viewModel: .init(chatRoom: ChatRoom(
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
        lastMessageSenderId: "Wv5HZZ3NMOQysA9VqEUdgdGQs713")))
}
