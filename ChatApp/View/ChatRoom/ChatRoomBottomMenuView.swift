//
//  ChatRoomBottomMenuView.swift
//  ChatApp
//
//  Created by window1 on 4/22/25.
//

import SwiftUI
import Combine
import _PhotosUI_SwiftUI

struct ChatRoomBottomMenuView: View {
    @ObservedObject var viewModel: ChatLogViewModel
    @State var isPresentedImagePicker: Bool = false
    @State var isPresentedCamera: Bool = false
    
    var body: some View {
        ScrollView {
            LazyVStack {
                HStack(spacing: 20) {
                    
                    Button {
                        isPresentedImagePicker.toggle()
                    } label: {
                        
                        VStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 30))
                                .frame(width: 60, height: 60)
                                .background(Color.gray.opacity(0.2))
                                .foregroundStyle(Color.green)
                                .clipShape(.circle)
                            Text("앨범")
                                .font(.system(size: 13, weight: .light))
                                .foregroundStyle(.black)
                        }
                    }
                    .sheet(isPresented: $isPresentedImagePicker) {
                        ChatRoomPhotosPciker(viewModel: viewModel)
                            .presentationDetents([.height(300), .large])
                            .presentationDragIndicator(.visible)
                            .presentationBackgroundInteraction(.enabled)
                    }

                    Button{
                        isPresentedCamera.toggle()
                    }label: {
                        VStack {
                            Image(systemName: "camera.on.rectangle.fill")
                                .font(.system(size: 30))
                                .frame(width: 60, height: 60)
                                .background(Color.gray.opacity(0.2))
                                .foregroundStyle(Color.blue)
                                .clipShape(.circle)
                            Text("카메라")
                                .font(.system(size: 13, weight: .light))
                                .foregroundStyle(.black)
                        }
                    }
                    .fullScreenCover(isPresented: $isPresentedCamera) {
                        CameraView()
                    }
                    Spacer()
                }
                .padding(10)
            }
        }
    }
}

#Preview {
    ChatRoomBottomMenuView(viewModel: .init(chatRoom: ChatRoom(
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
        lastMessageSenderId: "Wv5HZZ3NMOQysA9VqEUdgdGQs713")))
}

struct ChatRoomPhotosPciker: View {
    @ObservedObject var viewModel: ChatLogViewModel
    var body: some View {
        PhotosPicker (
            selection: $viewModel.selectedImage,
            selectionBehavior: .continuousAndOrdered,
            matching: .images,
            preferredItemEncoding: .current,
            photoLibrary: .shared()
        ) {
            
        }
        .photosPickerStyle(.inline)
        .photosPickerDisabledCapabilities(.selectionActions)
    }
}
