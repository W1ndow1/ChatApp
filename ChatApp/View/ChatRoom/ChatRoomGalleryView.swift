import SwiftUI

struct ChatRoomGalleryView: View {
    @StateObject var viewModel = ImageViewerViewModel()
    @State private var dragOffset: CGSize = .zero
    @GestureState private var isDragging: Bool = false
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var showUI: Bool = true

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            TabView(selection: $viewModel.currentIndex) {
                ForEach(viewModel.sampleImages.indices, id: \.self) { index in
                    ZoomableImageView(
                        image: viewModel.sampleImages[index],
                        showUI: $showUI,
                        onDismiss: {
                            viewModel.isDismissed = true
                        }
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .opacity(viewModel.isDismissed ? 0 : 1)
            .animation(.easeInOut, value: viewModel.isDismissed)

            if showUI {
                VStack {
                    HStack {
                        Button {
                            viewModel.isDismissed = true
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

                    Text("\(viewModel.currentIndex + 1) / \(viewModel.sampleImages.count)")
                        .font(.headline)
                        .padding(.bottom, 30)
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(10)
                }
                .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $viewModel.isDismissed) {
            // ChatRoomView로 돌아가는 것처럼 처리 가능
        }
    }
}

#Preview {
    ChatRoomGalleryView()
}

struct ZoomableImageView: View {
    let image: UIImage
    @Binding var showUI: Bool
    var onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            Circle()
                .frame(width: 30, height: 30)
                .foregroundStyle(.blue)
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(y: dragOffset.height)
                .gesture(
                    TapGesture()
                        .onEnded {
                            withAnimation {
                                showUI.toggle()
                            }
                        }
                )
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value
                        }
                        .onEnded { _ in
                            lastScale = scale
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            // 상하 이동만
                            if abs(value.translation.width) < abs(value.translation.height) {
                                state = value.translation
                            }
                        }
                        .onEnded { value in
                            if abs(value.translation.height) > 150 {
                                onDismiss()
                            }
                        }
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

class ImageViewerViewModel: ObservableObject {
    @Published var sampleImages: [UIImage] = [
        UIImage(systemName: "photo")!,
        UIImage(systemName: "photo.fill")!,
        UIImage(systemName: "photo.circle")!
    ]

    @Published var currentIndex: Int = 0
    @Published var isDismissed: Bool = false
}
