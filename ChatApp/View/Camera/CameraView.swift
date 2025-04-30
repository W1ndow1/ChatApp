//
//  CameraView.swift
//  ChatApp
//
//  Created by window1 on 4/25/25.
//

import SwiftUI

struct CameraView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var viewModel = CameraViewModel()
    @State private var isShowEditPhotoView: Bool = false
    @State private var isSwitchingCamera: Bool = false
    
    var onComplete: (UIImage) -> ()
    
    private static let barHeightFactor = 0.15
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ViewfinderView(image: $viewModel.viewFinderImage)
                    .blur(radius: isSwitchingCamera ? 10 : 0)
                    .overlay(alignment: .top) {
                        ZStack {
                            Color.black
                                .opacity(0.75)
                                .frame(height: geo.size.height * Self.barHeightFactor)
                            HStack {
                                Spacer()
                                Button {
                                    viewModel.camera.stop()
                                    dismiss()
                                } label: {
                                    Text("완료")
                                        .foregroundStyle(.yellow)
                                }
                                .padding(.trailing, 25)
                            }
                        }
                    }
                    .overlay(alignment: .bottom) {
                        buttonView()
                            .frame(height: geo.size.height * Self.barHeightFactor)
                            .background(.black.opacity(0.75))
                    }
                    .overlay(alignment: .center) {
                        Color.clear
                            .frame(height: geo.size.height * (1 - (Self.barHeightFactor * 2)))
                            .accessibilityElement()
                            .accessibilityAddTraits([.isImage])
                    }
                    .background(.black)
            }
            .animation(.easeInOut(duration: 0.3), value: isSwitchingCamera)
            .task {
                await viewModel.camera.start()
            }
            .onChange(of: viewModel.capturedImage) { _, new in
                if new != nil {
                    isShowEditPhotoView = true
                }
            }
            .navigationDestination(isPresented: $isShowEditPhotoView) {
                EditPhotoView(viewModel: viewModel) {
                    if let image = viewModel.capturedImage {
                        onComplete(image)
                    }
                    dismiss()
                }
            }
            .navigationTitle("카메라")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .ignoresSafeArea()
            .statusBar(hidden: true)
        }
    }
    @ViewBuilder
    private func buttonView() -> some View {
        HStack(spacing: 60) {
            Spacer()
            Button {
                print("globe")
            } label: {
                Label("하이요", systemImage: "globe")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            Button {
                viewModel.camera.takePhoto()
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                        .frame(width: 62, height: 62)
                    Circle()
                        .fill(.white)
                        .frame(width: 50, height: 50)
                }
            }
            
            Button {
                Task {
                    withAnimation(.easeIn(duration: 0.3)) {
                        isSwitchingCamera = true
                    }
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.5초
                }
                viewModel.camera.switchCaptureDevice()
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.5초
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isSwitchingCamera = false
                    }
                }
            } label: {
                Label("Switch Camera", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .buttonStyle(.plain)
        .labelStyle(.iconOnly)
        .padding()
    }
}

#Preview {
    CameraView(onComplete: { _ in })
}

struct ViewfinderView: View {
    @Binding var image: Image?
    
    var body: some View {
        GeometryReader { geometry in
            if let image = image {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
}
