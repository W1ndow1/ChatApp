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
    private static let barHeightFactor = 0.15
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ViewfinderView(image: $viewModel.viewFinderImage)
                    .overlay(alignment: .top) {
                        ZStack {
                            Color.black
                                .opacity(0.75)
                                .frame(height: geo.size.height * Self.barHeightFactor)
                            HStack {
                                Spacer()
                                Button {
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
                    .background(.white)
            }
            .task {
                await viewModel.camera.start()
            }
            .navigationTitle("카메라")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .ignoresSafeArea()
            .statusBar(hidden: true)
            /*
            .toolbar{
                ToolbarItem(placement:.topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("완료")
                            .foregroundStyle(.yellow)
                    }
                }
            }
             */
        }
    }
    @ViewBuilder
    private func buttonView() -> some View {
        HStack(spacing: 60) {
            Spacer()
            Button {
                
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
                viewModel.camera.switchCaptureDevice()
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
    CameraView()
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
