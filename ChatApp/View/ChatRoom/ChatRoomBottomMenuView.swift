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
    @State private var isPresentedImagePicker: Bool = false
    @State private var isPresentedCamera: Bool = false
    @State private var selectedImages: [PhotosPickerItem] = []
    @GestureState private var dragOffset: CGSize = .zero
    @Environment(\.dismiss) private var dismiss
    
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
                                .foregroundStyle(Color.buttonTitle)
                        }
                    }
                    .sheet(isPresented: $isPresentedImagePicker) {
                        chatRoomPhotosPicker()
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
                                .foregroundStyle(Color.buttonTitle)
                        }
                    }
                    .fullScreenCover(isPresented: $isPresentedCamera) {
                        CameraView() { image in
                            viewModel.captureIamge = image
                            viewModel.sendImage()
                            
                        }
                    }
                    Spacer()
                }
                .padding(10)
            }
        }
    }
    
    @ViewBuilder
    func chatRoomPhotosPicker() -> some View {
        PhotosPicker (
            selection: $selectedImages,
            selectionBehavior: .continuous,
            matching: .images,
            preferredItemEncoding: .current,
            photoLibrary: .shared()
        ) {
        }
        .photosPickerStyle(.inline)
        .onChange(of: selectedImages) { _, newItems in
            Task { @MainActor in
                viewModel.selectedImage = newItems
                
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


