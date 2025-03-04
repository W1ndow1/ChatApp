//
//  EditUserInfoView.swift
//  ChatApp
//
//  Created by window1 on 3/1/25.
//

import SwiftUI
import PhotosUI
import SDWebImageSwiftUI

struct EditUserInfoView: View {
    @ObservedObject var svm: SettingViewModel
    @StateObject var viewModel = LoginViewModel()
    @State private var selectedItem: PhotosPickerItem?
    var body: some View {
        NavigationStack {
            VStack{
                profileImageView()
                inputFiledView()
                Spacer()
            }
            .padding(.horizontal, 10)
            .navigationTitle("사용자 정보 수정")
            .navigationBarTitleDisplayMode(.inline)
        }
        .toolbar {
            navigationBarContent()
        }
    }
    @ToolbarContentBuilder
    func navigationBarContent() -> some ToolbarContent {
        ToolbarItem(placement:.topBarTrailing) {
            HStack(spacing: 5) {
                Button {
                    viewModel.editUserInfoButtonTap()
                } label: {
                    Text("확인")
                        .foregroundStyle(Color(.label))
                }
            }
        }
    }
    
    @ViewBuilder
    func profileImageView() -> some View {
        PhotosPicker(
            selection:$selectedItem,
            matching: .images,
            photoLibrary: .shared()) {
                VStack {
                    if let image = viewModel.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 140)
                            .clipShape(Circle())
                    } else if svm.currentUser?.profileImageURL != nil {
                        WebImage(url: URL(string: svm.currentUser?.profileImageURL ?? ""))
                            .resizable()
                            .scaledToFit()
                            .frame(height: 140)
                            .clipShape(Circle())
                    }
                }
                .overlay(Circle().stroke(.tint, lineWidth: 4))
                .padding(.vertical, 20)
                
            }
            .onChange(of: selectedItem, { oldItem, newItem in
                guard let newItem = newItem else { return }
                Task {
                    if let image = try? await newItem.loadTransferable(type: Data.self){
                        viewModel.image = UIImage(data: image)
                    }
                }
            })
    }
    @ViewBuilder
    func inputFiledView() -> some View {
        Group {
            TextField(text: $viewModel.displayName, label: {
                Text("닉네임")
            })
        }
        .padding(12)
        .overlay(content: {
            RoundedRectangle(cornerRadius: 20)
                .stroke(style: StrokeStyle(lineWidth: 0.8))
        })
        Text(viewModel.statusMessage)
            .font(.system(size: 15))
            .padding(.top, 10)
    }
    @ViewBuilder
    func editButtonView() -> some View {
        Button {
            viewModel.editUserInfoButtonTap()
        } label: {
            Text("확인")
                .frame(maxWidth: .infinity)
                .font(.system(size: 18, weight: .none))
                .foregroundStyle(.background)
                .padding(15)
                .background(.tint, in: RoundedRectangle(cornerRadius: 20))
        }
    }

}

#Preview {
    EditUserInfoView(svm: .init())
}


