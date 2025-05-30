import SwiftUI
import FirebaseCore
import SDWebImageSwiftUI
import Photos

struct ChatRoomGalleryView: View {
    var images: [GalleryImageItem]
    var startIndex: Int
    var namespace: Namespace.ID
    @Binding var isPresented: Bool
    
    @StateObject var galleryVM = GalleryViewModel()
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastoffset: CGSize = .zero
    @State private var tapPosition: CGPoint = .zero
    @State private var showTopBottomView: Bool = true
    @State private var showSaveAlert: Bool = false
    @State private var isDragging = false
    @State private var tapTimer: DispatchWorkItem?
    @State private var currentImageSize: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geo in
            if isPresented {
                ZStack {
                    Rectangle()
                        .foregroundStyle(showTopBottomView ? Color.whiteBlack : Color.black)
                        .ignoresSafeArea()
                        .zIndex(1)
                    TabView(selection: $galleryVM.currentIndex) {
                        ForEach(images.indices, id: \.self) { index in
                            galleryImage(for: index)
                                .ignoresSafeArea()
                                .tag(index)
                        }
                        
                    }
                    .ignoresSafeArea()
                    .zIndex(2)
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .gesture(verticalDragGesture().simultaneously(with: zoomedDragGesture(geo)))
                    .simultaneousGesture(magnificationGesture())
                    .simultaneousGesture(tapGesture(geo: geo).simultaneously(with: recordTapPosition()))
                    .onAppear {
                        galleryVM.setImages(images, startIndex)
                    }
                    .onDisappear {
                        galleryVM.currentIndex = 0
                    }
                    topBottomView()
                        .zIndex(3)
                        .animation(.easeInOut(duration: 0.2), value: showTopBottomView)
                }
            }
        }
    }
    
    @ViewBuilder
    private func topBottomView() -> some View {
        VStack {
            //상단 패널
            if showTopBottomView {
                HStack{
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "chevron.backward")
                            .foregroundStyle(.tint)
                            .font(.system(size: 20, weight: .regular))
                    }
                    .padding(.leading, 10)
                    
                    Spacer()
                    
                    VStack {
                        Text("\(images[galleryVM.currentIndex].userName)")
                            .font(.system(size: 16, weight: .medium))
                        Text("\(images[galleryVM.currentIndex].sendDate.dateValue().toString(dateFormat: "yyyy. M. d. a h:mm"))")
                            .font(.system(size: 12, weight: .light))
                    }
                    Spacer()
                    
                    Button {
                        
                    } label: {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 20))
                            .opacity(0.0)
                            .padding(.trailing, 10)
                    }
                }
                .padding(.vertical, 10)
                .background(Color.whiteBlack)
                .transition(.move(edge: .top)) // 상단은 위에서 등장
            }
            
            Spacer()
            
            //하단 패널
            if showTopBottomView {
                HStack(spacing: 30) {
                    Spacer()
                    Group {
                        saveButton()
                        shareButton()
                        Button {
                            //편집
                        } label: {
                            Image(systemName: "wand.and.rays.inverse")
                        }
                        
                        Button {
                            //삭제
                        } label: {
                            Image(systemName: "trash")
                            
                        }
                    }
                    .padding(10)
                    .background(Color.gray.opacity(0.5))
                    .clipShape(Circle())
                    .font(.system(size: 20, weight: .medium))
                    Spacer()
                }
                .padding(.vertical, 10)
                .background(Color.whiteBlack)
                .transition(.move(edge: .bottom)) // 상단은 위에서 등장
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
    
    @ViewBuilder
    private func galleryImage(for index: Int) -> some View {
        WebImage(url: URL(string: images[index].url))
            .resizable()
            .scaledToFit()
            .matchedGeometryEffect(id: images[index].id, in: namespace, properties: .frame)
            .scaleEffect(galleryVM.currentIndex == index ? scale : 1.0)
            .offset(galleryVM.currentIndex == index ? CGSize(
                width: dragOffset.width + offset.width,
                height: dragOffset.height + offset.height) : .zero)

    }
    
    //싱글탭 더블탭 이벤트 처리
    private func tapGesture(geo: GeometryProxy) -> some Gesture {
        let singleTap = TapGesture()
            .onEnded {
                tapTimer = DispatchWorkItem {
                    withAnimation {
                        showTopBottomView.toggle()
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: tapTimer!)
            }
        
        let doubleTap = TapGesture(count: 2)
            .onEnded {
                tapTimer?.cancel()
                
                if scale == 1.0 {
                    let imageFrame = calculateImageFrame(in: geo, imageSize: galleryVM.sharedImage.size)
                    guard imageFrame.contains(tapPosition) else { return }
                    
                    
                    let relativeX = (tapPosition.x - imageFrame.origin.x) / imageFrame.width
                    let relativeY = (tapPosition.y - imageFrame.origin.y) / imageFrame.height
                    
                    let newOffsetX = (0.5 - relativeX) * imageFrame.width * (2.0 - 1.0)
                    let newOffsetY = (0.5 - relativeY) * imageFrame.height * (2.0 - 1.0)
                    
                    offset = CGSize(width: newOffsetX, height: newOffsetY)
                    
                    withAnimation {
                        scale = 2.0
                    }
                    
                } else {
                    offset = .zero
                    lastoffset = .zero
                    
                    withAnimation {
                        scale = 1.0
                    }
                }
            }
        return SimultaneousGesture(singleTap, doubleTap)
    }
    
    
    //상하 좌우 이동(배율있을때만)
    private func zoomedDragGesture(_ geo: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1.0 {
                    if !isDragging {
                        lastoffset = offset
                        isDragging = true
                    }
                    
                    let proposedOffset = CGSize(
                        width: lastoffset.width + value.translation.width,
                        height: lastoffset.height + value.translation.height
                    )
                    offset = clampedOffset(proposedOffset: proposedOffset, geo: geo)
                }
            }
            .onEnded { value in
                if scale > 1.0 {
                    lastoffset = offset
                }
                isDragging = false
            }
    }
    private func clampedOffset(proposedOffset: CGSize, geo: GeometryProxy) -> CGSize {
        // 확대된 이미지의 가상 너비/높이
        let zoomedImageWidth = geo.size.width * scale
        let zoomedImageHeight = geo.size.height * scale
        
        let viewWidth = geo.size.width
        let viewHeight = geo.size.height
        
        // 이미지가 이동할 수 있는 최대/최소 범위 계산
        // (zoomedImage - viewSize) / 2 가 각 방향으로 이동할 수 있는 최대 오프셋입니다.
        let maxOffsetX = max((zoomedImageWidth - viewWidth) / 2, 0)
        let maxOffsetY = max((zoomedImageHeight - viewHeight) / 2, 0)
        
        // 오프셋 제한
        let clampedWidth = max(-maxOffsetX, min(maxOffsetX, proposedOffset.width))
        let clampedHeight = max(-maxOffsetY, min(maxOffsetY, proposedOffset.height))
        
        return CGSize(width: clampedWidth, height: clampedHeight)
    }
    
    
    //상하 이동시 닫기(배율없을때만)
    private func verticalDragGesture() -> some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                if scale == 1.0 {
                    if abs(value.translation.height) > abs(value.translation.width) {
                        state = value.translation
                    }
                }
            }
            .onEnded { value in
                if scale == 1.0 {
                    if (abs(value.translation.height) > 200 || abs(value.translation.height) < -200) {
                        isPresented = false
                    }
                }
            }
    }
    //핀치 확대
    private func magnificationGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                self.scale = max(value, 1.0)
            }
            .onEnded { _ in
                if scale < 1.0 {
                    withAnimation{
                        scale = 1.0
                        offset = .zero
                    }
                } else {
                    lastoffset = offset
                }
            }
    }
   
    //이미지 가로 세로 구분하기
    private func calculateImageFrame(in geo: GeometryProxy, imageSize: CGSize) -> CGRect {
        let containerSize = geo.size
        let imageRatio = imageSize.width / imageSize.height
        let containerRatio = containerSize.width / containerSize.height
        
        if imageRatio > containerRatio {
            // 이미지가 더 넓음: 가로 기준 맞춤
            let height = containerSize.width / imageRatio
            let y = (containerSize.height - height) / 2
            return CGRect(x: 0, y: y, width: containerSize.width, height: height)
        } else {
            // 이미지가 더 좁음: 세로 기준 맞춤
            let width = containerSize.height * imageRatio
            let x = (containerSize.width - width) / 2
            return CGRect(x: x, y: 0, width: width, height: containerSize.height)
        }
    }
    //터치시 위치 저장
    private func recordTapPosition() -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                tapPosition = value.location
            }
    }
}

#Preview {
    let namespace = Namespace.init().wrappedValue
    ChatRoomGalleryView(images: [GalleryImageItem(
        id: "1",
        url:"""
            https://i.ytimg.com/vi/x-BT2MXQwCs/hqdefault.jpg?v=682ff8fe&sqp=-oaymwEnCNACELwBSFryq4qpAxkIARUAAIhCGAHYAQHiAQoIGBACGAY4AUAB&rs=AOn4CLAIj0iC7fv_wB-qDO7AxDyUR1uxfA
            """,
        userName: "홍길주",
        sendDate:  Timestamp(date: Date())),
        
        GalleryImageItem(
        id: "2",
        url:"""
            https://i.ytimg.com/vi/hYGM2XWo600/hqdefault.jpg?sqp=-oaymwEnCNACELwBSFryq4qpAxkIARUAAIhCGAHYAQHiAQoIGBACGAY4AUAB&rs=AOn4CLBH1i7o2yrnGB8K5GmxygPFJvKAIg
            """ ,
        userName: "홍길철",
        sendDate:  Timestamp(date: Date())),
        GalleryImageItem(
        id: "3",
        url:"""
            https://pbs.twimg.com/media/GrhceqkXUAAQk3C?format=jpg&name=large
            """ ,
        userName: "홍길수",
        sendDate:  Timestamp(date: Date())),
        GalleryImageItem(
        id: "4",
        url:"""
            https://imgnews.pstatic.net/image/436/2025/05/23/0000098417_001_20250523153813683.jpeg?type=w647
            """ ,
        userName: "홍길소",
        sendDate:  Timestamp(date: Date())),
         
    ],
                        startIndex: 0,
                        namespace: namespace ,
                        isPresented: .constant(false))
}



struct SharedImage: Transferable {
    
    public var image: Image
    
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.image)
    }
}
