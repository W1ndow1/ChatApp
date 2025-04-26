//
//  ChatRoomSettingView.swift
//  ChatApp
//
//  Created by window1 on 3/27/25.
//

import SwiftUI

struct ChatRoomSettingView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
                /*
                 (1)채팅방 이미지 설정
                 (2)채팅방 이름 설정
                 (3)채팅방 배경화면
                 (4)채팅방 입력설정
                 (5)채팅방 내용 내보내기
                 (6)채팅방 나가기
                 (7)초대금지
                 */
            }
            .navigationTitle("채팅방 환경설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("나가기")
                            .font(.system(size: 15, weight: .bold))
                    }
                }
            }
        }
    }
}

#Preview {
    ChatRoomSettingView()
}
