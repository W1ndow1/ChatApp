import SwiftUI
import FirebaseCore
import SDWebImageSwiftUI
import Photos

struct ChatRoomGalleryView: View {
    var images: [GalleryImageItem]
    var startIndex: Int
    var namespace: Namespace.ID
    
    @StateObject var galleryVM = GalleryViewModel()
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastoffset: CGSize = .zero
    @State private var tapPosition: CGPoint = .zero
    @State private var showTopBottomView: Bool = true
    @State private var showSaveAlert: Bool = false
    @State private var tapTimer: DispatchWorkItem?
    @GestureState private var dragOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Rectangle()
                    .foregroundStyle(showTopBottomView ? Color.whiteBlack : Color.black)
                    .ignoresSafeArea()
                    .zIndex(1)
                TabView(selection: $galleryVM.currentIndex) {
                    ForEach(images.indices, id: \.self) { index in
                        VStack{
                            Spacer()
                            galleryImage(for: index)
                                .tag(index)
                                .ignoresSafeArea()
                            Spacer()
                        }
                    }
                }
                .zIndex(2)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .gesture(verticalDragGesture().simultaneously(with: zoomedDragGesture()))
                .simultaneousGesture(magnificationGesture())
                .simultaneousGesture(tapGesture(geo: geo).simultaneously(with: recordTapPosition()))
                .onAppear {
                    galleryVM.setImages(images, startIndex)
                }
                topBottomView()
                    .zIndex(3)
                    .animation(.easeInOut, value: showTopBottomView)
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
    //상하 좌우 이동(배율있을때만)
    private func zoomedDragGesture() -> some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1.0 {
                    offset = CGSize (
                        width: lastoffset.width + value.translation.width,
                        height: lastoffset.height + value.translation.height
                        )
                }
            }
            .onEnded { value in
                if scale > 1.0 {
                    lastoffset = offset
                }
            }
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
    //터치시 위치 저장
    private func recordTapPosition() -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                tapPosition = value.startLocation
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
}

#Preview {
    let namespace = Namespace.init().wrappedValue
    ChatRoomGalleryView(images: [GalleryImageItem(
        id: "",
        url: "",
        userName: "홍길동",
        sendDate: Timestamp(date: Date()))],
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
