//
//  ChatRoomMessageView.swift
//  ChatApp
//
//  Created by window1 on 4/29/25.
//

import SwiftUI
import SDWebImageSwiftUI
import FirebaseCore

struct ChatRoomMessageView: View {
    @ObservedObject var viewModel: ChatLogViewModel
    @Binding var msg: ChatMessage
    var body: some View {
        if msg.senderId != AuthManager.shared.id {
            otherMessage(msg: msg)
        } else {
            myMessage(msg: msg)
        }
    }
    
    @ViewBuilder
    private func otherMessage(msg: ChatMessage) -> some View {
        HStack(alignment: .top) {
            if (msg.isFirstInTimeGroup) || !(msg.isFromSameSender) {
                WebImage(url: URL(string: viewModel.usersInfo?[msg.senderId]?.profileImageURL ?? ""))
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
                if (msg.isFirstInTimeGroup) || !(msg.isFromSameSender) {
                    Text(viewModel.usersInfo?[msg.senderId]?.displayName ?? "")
                        .font(.system(size: 10, weight: .light))
                }
                HStack(alignment: .bottom) {
                    if msg.type == .image {
                        WebImage(url: URL(string: msg.text))
                            .resizable()
                            .retryOnAppear(true)
                            .scaledToFit()
                            .frame(width: 230)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                    } else {
                        Text(msg.text)
                            .padding(8)
                            .background(Color.white)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .frame(minWidth: 30, alignment: .leading)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                    }
                    if (msg.isFirstInTimeGroup) || !(msg.isFromSameSender) {
                        Text(msg.timeStamp.dateValue().toString(dateFormat: "a h:mm"))
                            .font(.system(size: 10, weight: .light))
                    }
                    Spacer()
                }
                .padding(.vertical, 3)
            }
            .padding(.trailing, 30)
        }
        Spacer()
    }
    
    @ViewBuilder
    private func myMessage(msg: ChatMessage) -> some View {
        Spacer()
        HStack(alignment: .bottom) {
            Spacer()
            if (msg.isFirstInTimeGroup) || !(msg.isFromSameSender) {
                Text(msg.timeStamp.dateValue().toString(dateFormat: "a h:mm"))
                    .font(.system(size: 10, weight: .light))
            }
            if msg.type == .image {
                switch msg.sendState {
                case .sending:
                    ProgressView()
                        .foregroundStyle(.tint)
                case .sent:
                    WebImage(url: URL(string: msg.text))
                        .resizable()
                        .retryOnAppear(true)
                        .scaledToFit()
                        .frame(width: 230)
                        .background(.tint)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                case .failed:
                    Button {
                        if viewModel.captureIamge != nil {
                            viewModel.sendImage()
                        }
                    } label: {
                        Image(systemName: "paperplane.circle")
                            .font(.system(size: 15))
                            .foregroundStyle(.tint)
                    }
                }
                
            } else {
                Text(msg.text)
                    .padding(8)
                    .foregroundStyle(Color.white)
                    .background(.tint)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .frame(minWidth: 30, alignment: .trailing)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.leading, 30)
    }
}

#Preview {
    ChatRoomMessageView(viewModel: .init(chatRoom: ChatRoom(
        chatRoomType: .group,
        chatRoomId: """
                    UyZOQtY9occyvmxpP82jr7QdEP12_
                    WDznGLHspLevJ0kgC9m783bUtWB3_
                    Wv5HZZ3NMOQysA9VqEUdgdGQs713_
                    uBzmBwnRmdbkCFoBls9DHa4uC8j2
                    """,
        chatRoomMakerId: "Wv5HZZ3NMOQysA9VqEUdgdGQs713",
        participants: ["Wv5HZZ3NMOQysA9VqEUdgdGQs713",
                       "uBzmBwnRmdbkCFoBls9DHa4uC8j2"],
        chatName: "Malone,지구본,Time",
        lastMessageTimeStamp: .init(date: Date()),
        lastMessageSenderId: "Wv5HZZ3NMOQysA9VqEUdgdGQs713")
    ), msg: .constant(ChatMessage(
        messageId: "123123",
        type: .image,
        senderId: "Wv5HZZ3NMOQysA9VqEUdgdGQs713",
        text: "https://firebasestorage.googleapis.com:443/v0/b/swiftui-firebase-chetapp.firebasestorage.app/o/images%2FsGh4Gxdz6sQ4OtoFAg1RLZNFH893.jpeg?alt=media&token=7e2d3186-cf5b-4932-9d37-86bb664831db",
        timeStamp: Timestamp(date: Date()),
        readBy: [],
        sendState: .sending
    )))
}
