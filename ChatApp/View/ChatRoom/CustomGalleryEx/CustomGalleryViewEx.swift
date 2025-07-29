//커스텀 겔러리뷰 이미지 뷰를 UIKit 기반으로 다시 작성해보자
//이미지뷰를 UIkit의 UIImageView로 swiftui의 image를 대체

import SwiftUI
import FirebaseCore


struct CustomGalleryViewEx: View {
    var images: [GalleryImageItem]
    var startIndex: Int = 0
    @Binding var isPresented: Bool
    
    @StateObject var galleryVM = GalleryViewModel()
    
    @State private var currentZoomScale: CGFloat = 1.0
    @State private var selectedPage: Int = 0
    //드래그 제스쳐
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    //UI 상태 변수
    @State private var showSaveAlert: Bool = false

    
    var body: some View {
        GeometryReader { geo in
            if isPresented {
                ZStack {
                    //배경
                    Color.black
                        .ignoresSafeArea()
                        .foregroundStyle(galleryVM.showTopBottomView ? Color.whiteBlack : Color.black)
                        .zIndex(1)
                    //이미지
                    HStack(spacing: 20) {
                        PageViewController(
                            galleryItems: images,
                            initialPageIndex: startIndex,
                            currentPage: $selectedPage,
                            showTopBottomView: $galleryVM.showTopBottomView
                        )
                    }
                    .zIndex(2)
                    .onAppear {
                        galleryVM.setImages(images, startIndex)
                        selectedPage = startIndex
                    }
                    .onDisappear {
                        galleryVM.currentIndex = 0
                        galleryVM.showTopBottomView = true
                    }
                    .offset(y: dragOffset.height)
                    .gesture(drageGesture())
                    
                    //상, 하단 프레임
                    topBottomView(geo)
                        .zIndex(3)
                        .frame(maxWidth: geo.size.width, maxHeight: geo.size.height, alignment: .topLeading)
                    
                }
                .opacity(backgroundOpacity)
            }
        }
    }
    @ViewBuilder
    private func topBottomView(_ geo: GeometryProxy) -> some View {
        VStack {
            if galleryVM.showTopBottomView {
                //상단
                HStack {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "chevron.backward")
                            .foregroundStyle(.tint)
                            .font(.system(size: 20, weight: .regular))
                    }
                    .padding(.leading, 20)
                    Spacer()
                    VStack {
                        Text("\(images[galleryVM.currentIndex].userName)")
                            .font(.system(size: 16, weight: .medium))
                        Text("\(images[galleryVM.currentIndex].sendDate.dateValue().toString(dateFormat: "yyyy. M. d. a h:mm"))")
                            .font(.system(size: 12, weight: .light))
                    }
                    Spacer()
                    Button {
                        //전체보기 이벤트
                    } label: {
                         Image(systemName: "square.grid.2x2")
                            .font(.system(size: 20, weight: .regular))
                    }
                    .padding(.trailing, 20)
                }
                .padding(.vertical, 10)
                .background(Color.whiteBlack)
                .transition(.move(edge: .top))

                Spacer()
                
                //하단
                HStack(spacing: 50) {
                    Group {
                        saveButton()
                        shareButton()
                        Button {
                            //편집
                        } label: {
                            Image(systemName: "wand.and.rays.inverse")
                                .foregroundStyle(.tint)
                        }
                        Button {
                            //삭제
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.tint)
                        }
                    }
                    .padding(10)
                    .background(Color.gray.opacity(0.5))
                    .clipShape(Circle())
                    .font(.system(size: 20, weight: .medium))
                }
                .frame(width: geo.size.width)
                .padding(.vertical, 10)
                .background(Color.whiteBlack)
                .transition(.move(edge: .bottom))
            }
        }
    }
    
    @ViewBuilder
    private func saveButton() -> some View {
        Button {
            showSaveAlert.toggle()
        } label: {
            Image(systemName: "arrow.down.circle")
        }
        .confirmationDialog("보관함에 사진을 저장하시겠습니까?", isPresented: $showSaveAlert, titleVisibility: .visible) {
            Button("확인", role: .destructive) {
                galleryVM.saveImageFromCache(urlString: images[galleryVM.currentIndex].url)
            }
            Button("취소", role: .cancel) { }
        }
    }
    
    @ViewBuilder
    private func shareButton() -> some View {
        ShareLink(item: Image(uiImage: galleryVM.sharedImage),
                  preview: SharePreview("공유이미지", image: Image(uiImage: galleryVM.sharedImage))) {
            Image(systemName: "square.and.arrow.up")
        }
    }
    
    private func drageGesture() -> some Gesture {
        DragGesture()
            .onChanged { value in
                if value.translation.height > 0 || value.translation.height < 0 {
                    dragOffset = value.translation
                    isDragging = true
                }
            }
            .onEnded { value in
                isDragging = false
                if currentZoomScale == 1.0 {
                    let dragDestance = value.predictedEndTranslation.height
                    let threshhold: CGFloat = 300
                    if dragDestance > threshhold || dragDestance < -threshhold {
                        isPresented.toggle()
                        isDragging = false
                    }
                    dragOffset = .zero
                }
            }
    }
    
    private var backgroundOpacity: Double {
        var result = 1.0
        let offset = abs(dragOffset.height)
        let maxOffset: CGFloat = 300
        let opacity = 1.0 - min(Double(offset / maxOffset), 1.0)
        result = opacity
        return result
    }
}

#Preview {
    CustomGalleryViewEx(images: [
        GalleryImageItem(
            id: "1",
            url:
            """
            https://i.ytimg.com/vi/x-BT2MXQwCs/hqdefault.jpg?v=682ff8fe&sqp=-oaymwEnCNACELwBSFryq4qpAxkIARUAAIhCGAHYAQHiAQoIGBACGAY4AUAB&rs=AOn4CLAIj0iC7fv_wB-qDO7AxDyUR1uxfA
            """,
            userName: "홍길동",
            sendDate: Timestamp(date: Date())),
        GalleryImageItem(
            id: "2",
            url:"""
            https://i.ytimg.com/vi/hYGM2XWo600/hqdefault.jpg?sqp=-oaymwEnCNACELwBSFryq4qpAxkIARUAAIhCGAHYAQHiAQoIGBACGAY4AUAB&rs=AOn4CLBH1i7o2yrnGB8K5GmxygPFJvKAIg
            """ ,
            userName: "홍길철",
            sendDate:  Timestamp(date: Date())),
    ],
                        startIndex: 0,
                        isPresented: .constant(true))
}
