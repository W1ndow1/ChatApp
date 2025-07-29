//
//  CustomGalleryView.swift
//  ChatApp
//
//  Created by window1 on 5/23/25.
//

import SwiftUI
import FirebaseCore
import SDWebImageSwiftUI

struct CustomGalleryView: View {
    var images: [GalleryImageItem]
    var startIndex: Int = 0
    var namespace: Namespace.ID
    @Binding var isPresented: Bool
    
    @StateObject var galleryVM = GalleryViewModel()

    //UI 상태 변수
    @State private var showSaveAlert: Bool = false

    //핀치 줌/팬 상태 저장을 위한 변수
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var bounceOffset: CGFloat = 0
    @State private var tapPosition: CGPoint = .zero
    @State private var activeDragAxis: DragAxis = .unknown
    
    //핀치 줌 저장
    @State private var anchorPoint: UnitPoint = .center
    @GestureState private var magniftyBy = 1.0
    @GestureState private var pinchLocation: CGPoint = .zero
    
    private var backgroundOpacity: Double {
        var result = 1.0
        if scale == 1.0 {
            let offset = abs(offset.height)
            let maxOffset: CGFloat = 300
            let opacity = 1.0 - min(Double(offset / maxOffset), 1.0)
            result = opacity
        }
        return result
    }
    
    let itemSpacing: CGFloat = 20
    
    var body: some View {
        GeometryReader { geo in
            if isPresented {
                ZStack(alignment: .leading) {
                    let screenWidth = geo.size.width
                    let screenHeight = geo.size.height
                    let itemFullWidth = screenWidth + itemSpacing
                    Group {
                        //배경
                        Rectangle()
                            .ignoresSafeArea()
                            .foregroundStyle(galleryVM.showTopBottomView ? Color.whiteBlack : Color.black)
                            .zIndex(1)
                        //이미지
                        HStack(spacing: itemSpacing) {
                            ForEach(images.indices, id: \.self) { index in
                                galleryImage(index, geo)
                                    .ignoresSafeArea()
                                    .tag(index)
                            }
                        }
                        .onAppear {
                            galleryVM.setImages(images, startIndex)
                        }
                        .onDisappear {
                            galleryVM.currentIndex = 0
                        }
                        .frame(height: screenHeight)
                        .zIndex(2)
                        .offset(x: -CGFloat(galleryVM.currentIndex) * itemFullWidth
                                + (scale == 1.0 ? offset.width + bounceOffset : 0))
                        .offset(y: scale == 1.0 ? offset.height : 0)
                        .gesture(TapGesture(count: 2).onEnded{ handleDoubleTap(geo) }).simultaneousGesture(recordTapPosition())
                        .gesture(magnificationGesture2(geo)).simultaneousGesture(dragGesture(geo))
                    }
                    .gesture(dragGesture(geo))
                    .gesture(TapGesture().onEnded { _ in galleryVM.showTopBottomView.toggle() })
                    //.gesture(TapGesture(count: 2).onEnded { _ in } )
                    
                    //상,하단 프레임
                    topBottomView(geo)
                        .zIndex(3)
                        .frame(maxWidth: geo.size.width, maxHeight: geo.size.height, alignment: .bottomLeading )
                        .animation(.easeInOut(duration: 0.2), value: galleryVM.showTopBottomView)
                }
                .opacity(backgroundOpacity)
            }
        }
    }
    
    @ViewBuilder
    private func topBottomView(_ geo: GeometryProxy) -> some View {
        VStack {
            if galleryVM.showTopBottomView {
                HStack{
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
                    .animation(nil, value: galleryVM.currentIndex)
                    Spacer()
                    
                    Button {
                        
                    } label: {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 20))
                            .opacity(0.0)
                    }
                    .padding(.trailing, 20)
                }
                .padding(.vertical, 10)
                .background(Color.whiteBlack)
                .transition(.move(edge: .top))
            }
            
            Spacer()
            
            if galleryVM.showTopBottomView {
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
    
    @ViewBuilder
    private func galleryImage(_ index: Int, _ geo: GeometryProxy) -> some View {
        WebImage(url: URL(string: images[index].url), options: .scaleDownLargeImages)
            .resizable()
            .scaledToFit()
            .frame(width: geo.size.width)
            .matchedGeometryEffect(id: images[index].id, in: namespace, properties: .frame)
            //.scaleEffect(galleryVM.currentIndex == index ?  scale * magniftyBy : 1.0, anchor: anchorPoint)
            .scaleEffect(galleryVM.currentIndex == index ?  scale : 1.0, anchor: anchorPoint)
            .offset(galleryVM.currentIndex == index ? offset : .zero)
    }
    
    private func magnificationGesture2(_ geo: GeometryProxy) -> some Gesture  {
        MagnificationGesture()
            .onChanged { value in
                scale = min(lastScale * value, 12.0)
                let unitX = tapPosition.x / geo.size.width
                let unitY = tapPosition.y / geo.size.height
                anchorPoint = UnitPoint(x: unitX, y: unitY)
            }
            .onEnded { value in
                withAnimation(.easeInOut(duration: 0.25)) {
                    if scale < 1.0 {
                        scale = 1.0
                        lastScale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    } else if scale > 8.0 {
                        scale = 8.0
                        lastScale = 8.0
                    } else {
                        lastScale = scale
                    }
                }
            }
    }
    
    private func magnificationGesture(_ geo: GeometryProxy) -> some Gesture {
        MagnifyGesture()
            .updating($magniftyBy) { value, state, transaction in
                state = value.magnification
                let start = value.startLocation
                let unitX = start.x / geo.size.width
                let unitY = start.y / geo.size.height
                anchorPoint = UnitPoint(x: unitX, y: unitY)
            }
            .onEnded { value in
                if scale < 1.0 {
                    withAnimation {
                        scale = 1.0
                        lastScale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    }
                } else {
                    let finalMagnification = value.magnification
                    let newScale = lastScale * finalMagnification
                    scale = min(max(newScale, 1.0), 8.0)
                    lastScale = scale
                }
            }
    }
    
    //더블 탭으로 2배 확대, 터치한 곳을 기준으로 이동
    private func handleDoubleTap(_ geo: GeometryProxy) {
        let imageSize = imageSizeInContainer(containerSize: geo.size)
        let newScale: CGFloat = scale == 1.0 ? 3.0 : 1.0
        if scale == 1.0 {
            
            // 현재 탭한 위치 기준 비율
            let relativeX = tapPosition.x / geo.size.width
            let relativeY = tapPosition.y / geo.size.height
            
            // 스케일 변화량
            let scaleDelta = newScale - 1.0
            
            // 확대 시 필요한 offset
            var newOffsetX = (0.5 - relativeX) * imageSize.width * scaleDelta
            var newOffsetY = (0.5 - relativeY) * imageSize.height * scaleDelta
            
            // 확대 후 이미지 크기
            let scaledWidth = imageSize.width * newScale
            let scaledHeight = imageSize.height * newScale
            
            // 화면 크기 기준 최대 offset
            let maxOffsetX = (scaledWidth - imageSize.width) / 2
            let maxOffsetY = (scaledHeight - imageSize.height) / 2
            
            // offset이 이미지 프레임을 넘어가지 않도록 clamp
            newOffsetX = min(max(newOffsetX, -maxOffsetX), maxOffsetX)
            newOffsetY = min(max(newOffsetY, -maxOffsetY), maxOffsetY)
            
            withAnimation(.easeInOut(duration: 0.25)) {
                offset = CGSize(width: newOffsetX , height: newOffsetY)
                lastOffset = offset
                scale = newScale
                lastScale = scale
            }
            
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                offset = .zero
                lastOffset = .zero
                scale = 1.0
                lastScale = 1.0
                anchorPoint = .center
            }
        }
    }
    
    private func recordTapPosition() -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                tapPosition = value.location
            }
    }
    
    private func imageSizeInContainer(containerSize: CGSize) -> CGSize {
        let imageAspect: CGFloat = galleryVM.sharedImage.size.width / galleryVM.sharedImage.size.height
        let containerAspect = containerSize.width / containerSize.height

        if imageAspect > containerAspect {
            let width = containerSize.width
            let height = width / imageAspect
            return CGSize(width: width, height: height)
        } else {
            let height = containerSize.height
            let width = height * imageAspect
            return CGSize(width: width, height: height)
        }
    }
    
    private func clampedOffset(proposedOffset: CGSize, image: CGSize) -> CGSize {
        // 확대된 이미지의 가상 너비/높이
        let zoomedImageWidth = image.width * scale
        let zoomedImageHeight = image.height * scale
        
        let viewWidth = image.width
        let viewHeight = image.height
        
        // 이미지가 이동할 수 있는 최대/최소 범위 계산
        // (zoomedImage - viewSize) / 2 가 각 방향으로 이동할 수 있는 최대 오프셋입니다.
        let maxOffsetX = max((zoomedImageWidth - viewWidth) / 2, 0)
        let maxOffsetY = max((zoomedImageHeight - viewHeight) / 2, 0)
        
        // 오프셋 제한
        let clampedWidth = max(-maxOffsetX, min(maxOffsetX, proposedOffset.width))
        let clampedHeight = max(-maxOffsetY, min(maxOffsetY, proposedOffset.height))
        
        return CGSize(width: clampedWidth, height: clampedHeight)
    }
    
    
    //상하 좌우 움직일때 이벤트
    private func dragGesture(_ geo: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let currentImageSize = imageSizeInContainer(containerSize: geo.size)
                //배율이 있을때
                if scale > 1.0 {
                    let proposedOffset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                    offset = clampedOffset(proposedOffset: proposedOffset, image: currentImageSize)
                    anchorPoint = .center
                //배율이 없을때
                } else {
                    if activeDragAxis == .unknown {
                        if abs(value.translation.width) > abs(value.translation.height) {
                            activeDragAxis = .horizontal
                        } else {
                            activeDragAxis = .vertical
                        }
                    }
                    switch activeDragAxis {
                    case .horizontal:
                        offset = CGSize(width: value.translation.width / 4, height: 0)
                    case .vertical:
                        offset = CGSize(width: 0, height: value.translation.height / 3)
                        
                    case .unknown:
                        break
                    }
                }
            }
            .onEnded { value in
                if scale > 1.0 {
                    lastOffset = offset
                    return
                } else {
                    switch activeDragAxis {
                    case .horizontal:
                        let predicted = value.predictedEndTranslation.width
                        let threshold: CGFloat = 50
                        //왼쪽으로 스와이프
                        if predicted < -threshold {
                            if galleryVM.currentIndex < images.count - 1 {
                                withAnimation {
                                    galleryVM.currentIndex += 1
                                }
                            } else {
                                resetImageState()
                                bounce(direction: .right)
                                
                            }
                            //오른쪽으로 스와이프
                        } else if predicted > threshold {
                            if galleryVM.currentIndex > 0 {
                                withAnimation {
                                    galleryVM.currentIndex -= 1
                                }
                            } else {
                                resetImageState()
                                bounce(direction: .left)
                            }
                        }
                        
                    case .vertical:
                        let dragDistance = value.predictedEndTranslation.height
                        let threshhold: CGFloat = 100
                        //아래로 스와이프(사진이동방향⬇︎)       //위로 스와이프(사진이동방향⬆︎)
                        if dragDistance > threshhold || dragDistance < -threshhold{
                            resetImageState()
                            isPresented = false
                            return
                        }
                    case .unknown:
                        break
                    }
                }
                resetImageState()
                
            }
    }
    //양쪽끝에 도착하면 튕겨지는 효과
    private func bounce(direction: BounceDirection) {
        let bounceAmount: CGFloat = 20 // 튕겨 나가는 거리 (조절 가능)
        
        //  튕겨 나가는 애니메이션
        withAnimation(.easeOut(duration: 0.1)) {
            bounceOffset = (direction == .right ? -bounceAmount : bounceAmount)
        }
        
        // 원래 위치로 돌아오는 애니메이션
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // 튕겨 나간 후 바로 복귀 시작
            withAnimation(.easeOut(duration: 0.2)) { // 더 부드럽고 천천히 돌아오게
                bounceOffset = 0
            }
        }
    }
    //뷰 상태 초기화
    private func resetImageState() {
        withAnimation(.easeInOut) {
            offset = .zero
            lastOffset = .zero
            scale = 1.0
            lastScale = 1.0
            activeDragAxis = .unknown
            anchorPoint = .center
        }
    }
}

//드래그 방향
private enum DragAxis {
       case unknown, horizontal, vertical
   }
// 경계 바운스 애니메이션
private enum BounceDirection {
    case left, right
}

#Preview {
    let namespace = Namespace.init().wrappedValue
    CustomGalleryView(images: [
        GalleryImageItem(
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
                      namespace: namespace,
                      isPresented: .constant(false)
    )
}


