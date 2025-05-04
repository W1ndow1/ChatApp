import SwiftUI
import FirebaseCore
import SDWebImageSwiftUI

struct GalleryImageItem: Identifiable {
    let id: String
    let url: String
}

struct ChatRoomGalleryView: View {
    var images: [GalleryImageItem]
    var startIndex: Int
    var namespace: Namespace.ID
    
    @Binding var isPresented: Bool
    @State private var currentIndex = 0
    @GestureState private var dragOffset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastoffset: CGSize = .zero
    @State private var tapPosition: CGPoint = .zero
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                
                TabView(selection: $currentIndex) {
                    ForEach(images.indices, id: \.self) { index in
                        VStack{
                            Spacer()
                            galleryImage(for: index, geo: geo)
                                .tag(index)
                            Spacer()
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .gesture(verticalDragGesture().simultaneously(with: dragGesture()))
                .gesture(scale == 1.0 ? horizontalDragGesture() : nil)
                .simultaneousGesture(magnificationGesture())
                .simultaneousGesture(tapGesture(geo: geo).simultaneously(with: recordTapPosition()))
                .onAppear {
                    currentIndex = startIndex
                }
                topBar()
            }
        }
    }
    
    @ViewBuilder
    private func topBar() -> some View {
        VStack {
            HStack {
                Button {
                    withAnimation(.spring) {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 40)
            
            Spacer()
        }
        .foregroundStyle(.white)
    }
    
    @ViewBuilder
    private func galleryImage(for index: Int, geo: GeometryProxy) -> some View {
        WebImage(url: URL(string: images[index].url))
            .resizable()
            .scaledToFit()
            .matchedGeometryEffect(id: images[index].id, in: namespace)
            .scaleEffect(currentIndex == index ? scale : 1.0)
            .offset(currentIndex == index ? CGSize(width: dragOffset.width + offset.width,
                                                   height: dragOffset.height + offset.height) : .zero)
            .ignoresSafeArea()
    }
    
    //상하 좌우 이동(배율있을때만)
    private func dragGesture() -> some Gesture {
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
                        withAnimation(.spring) {
                            isPresented = false
                        }
                    }
                }
            }
    }
    //좌우 이동
    private func horizontalDragGesture() -> some Gesture {
        DragGesture()
            .onChanged { _ in }
            .onEnded { _ in }
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
    //더블탭시 확대
    private func tapGesture(geo: GeometryProxy) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation(.spring()) {
                    if scale == 1.0 {
                        scale = 3.0
                        let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                        let deltaX = (center.x - tapPosition.x)
                        let deltaY = (center.y - tapPosition.y)
                        offset = CGSize(width: deltaX * 2, height: deltaY * 2)
                    } else{
                        scale = 1.0
                        offset = .zero
                        lastoffset = .zero
                    }
                }
            }
    }
    
    private func recordTapPosition() -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                tapPosition = value.location
            }
    }
}

