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
    var msg: ChatMessage
    var imageNameSpace: Namespace.ID
    var onImageTap: ([GalleryImageItem], Int) -> ()
    
    @State private var image: UIImage?
    
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
            //보낸이 이미지
            if (msg.isFirstInTimeGroup) || !(msg.isFromSameSender) {
                WebImage(url: URL(string: viewModel.usersInfo?[msg.senderId]?.profileImageURL ?? ""), options: .scaleDownLargeImages)
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
                //보낸이 이름
                if (msg.isFirstInTimeGroup) || !(msg.isFromSameSender) {
                    Text(viewModel.usersInfo?[msg.senderId]?.displayName ?? "")
                        .font(.system(size: 10, weight: .light))
                }
                HStack(alignment: .bottom) {
                    //이미지
                    if msg.type == .image || msg.type == .images {
                        imageMessage(msg: msg)
                        //텍스트
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
                    //전송시간
                    if (msg.isFirstInTimeGroup) || !(msg.isFromSameSender) {
                        Text(msg.timeStamp.dateValue().toString(dateFormat: "a h:mm"))
                            .font(.system(size: 10, weight: .light))
                    }
                    Spacer()
                }
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
            //전송시간
            if (msg.isFirstInTimeGroup) || !(msg.isFromSameSender) {
                Text(msg.timeStamp.dateValue().toString(dateFormat: "a h:mm"))
                    .font(.system(size: 10, weight: .light))
            }
            //이미지
            if msg.type == .image || msg.type == .images {
                imageMessage(msg: msg)
            }
            //텍스트
            else {
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
    @ViewBuilder
    private func imageMessage(msg: ChatMessage) -> some View {
        switch msg.sendState {
        case .sending:
            ProgressView()
                .foregroundStyle(.tint)
        case .sent:
            if msg.type == .image {
                
                ResizedAsyncImage(url: URL(string: msg.text)!, targetSize: CGSize(width: 210, height: 210))
                    .scaledToFit()
                    .frame(width: 210)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .matchedGeometryEffect(id: msg.id, in: imageNameSpace)
                    .onTapGesture {
                        let allImages = viewModel.chatRoomImageMerge()
                        if let index = allImages.firstIndex(where: { $0.url == msg.text}) {
                            onImageTap(allImages, index)
                        }
                    }
                /*
                WebImage(url: URL(string: msg.text), options: [.scaleDownLargeImages, .progressiveLoad])
                    .resizable()
                    .scaledToFit()
                    .frame(width: 210)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .matchedGeometryEffect(id: msg.id, in: imageNameSpace)
                    .onTapGesture {
                        let allImages = viewModel.chatRoomImageMerge()
                        if let index = allImages.firstIndex(where: { $0.url == msg.text}) {
                            onImageTap(allImages, index)
                        }
                    }
                    .onLongPressGesture(perform: {
                        //이미지 저장
                    })
                 */
            } else if msg.type == .images {
                groupImageView2(msg: msg)
                    .frame(maxWidth:210, maxHeight: 210)
            }
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
    }
    
    @ViewBuilder
    private func groupImageView(msg: ChatMessage) -> some View {
        let maxVisibleImages = 4
        let imageCount = msg.imageURLs.count
        let displayURLs = Array(msg.imageURLs.prefix(maxVisibleImages))
        ZStack {
            ForEach(Array(displayURLs.enumerated()), id: \.offset) { index, url in
                WebImage(url: URL(string: url), options:[.scaleDownLargeImages, .progressiveLoad])
                    .resizable()
                    .interpolation(.low)
                    .scaledToFill()
                    .frame(width:160)
                    .background(.tint)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .offset(x: CGFloat(index) * 10)
                    .zIndex(Double(maxVisibleImages - index))
                    .onTapGesture {
                        let images = msg.imageURLs.map { GalleryImageItem(id: $0, url: $0)}
                        if let index = msg.imageURLs.firstIndex(of: url) {
                            onImageTap(images, index)
                        }
                    }
            }
            .padding(.trailing, CGFloat(10 * displayURLs.count))
            if imageCount > 1 {
                HStack {
                    Spacer()
                    VStack {
                        Text("\(imageCount)")
                            .padding(10)
                            .font(.system(size: 15, weight: .bold))
                            .background(.tint)
                            .foregroundStyle(Color.white)
                            .clipShape(Circle())
                        Spacer()
                    }
                }
                .zIndex(5)
            }
        }
    }
    
    @ViewBuilder
    private func groupImageView2(msg: ChatMessage) -> some View {
        let maxImages = 9 // 3x3으로 제한 (10개는 넘기지 않도록)
        let imageURLs = Array(msg.imageURLs.prefix(maxImages))
        let columns = Array(repeating: GridItem(.flexible(), spacing: 3) , count: 3)
        
        LazyVGrid(columns: columns, spacing: 5) {
            ForEach(imageURLs, id: \.self) { url in
                ResizedAsyncImage(url: URL(string: url)!, targetSize: CGSize(width: 65, height: 65))
                    .scaledToFill()
                    .frame(width: 65, height: 65)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .onTapGesture {
                        let images = msg.imageURLs.map { GalleryImageItem(id: $0, url: $0) }
                        if let index = msg.imageURLs.firstIndex(of: url) {
                            onImageTap(images, index)
                        }
                    }
            }
        }
        .padding(4)
    }
}


