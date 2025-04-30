//
//  EditPhotoView.swift
//  ChatApp
//
//  Created by window1 on 4/27/25.
//

import SwiftUI

struct EditPhotoView: View {
    @ObservedObject var viewModel: CameraViewModel
    
    var onComplete: () -> ()
    
    private static let barHeightFactor = 0.17
    
    var body: some View {
        GeometryReader { geo in
            VStack {
                Color.black
                    .frame(height: geo.size.height * Self.barHeightFactor)
                Spacer()
                if let image = viewModel.capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .border(Color.gray)
                } else {
                    Image(systemName: "globe")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .border(Color.gray)
                }
                Spacer()
                ZStack {
                    Color.black
                        .frame(height: geo.size.height * Self.barHeightFactor)
                    bottomButtonView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onComplete()
                    } label: {
                        Text("완료")
                            .foregroundStyle(.yellow)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
    
    @ViewBuilder
    func bottomButtonView() -> some View {
        HStack {
            Button {
                
            } label: {
                VStack(spacing: 10){
                    Image(systemName: "crop")
                        .font(.system(size: 30))
                        .foregroundStyle(.yellow)
                    Text("자르기")
                        .font(.system(size: 15))
                        .foregroundStyle(.yellow)
                }
            }
        }
    }
}

#Preview {
    EditPhotoView(viewModel: .init(), onComplete: {})
}
