//
//  RegistrationView.swift
//  ChatApp
//
//  Created by window1 on 2/10/25.
//

import SwiftUI
import PhotosUI

struct RegistrationView: View {
    @ObservedObject var viewModel: LoginViewModel
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    profileImageView()
                    inputFiledView()
                    signUpButtonView()
                    Text("\(viewModel.statusMessage)")
                }
                .padding()
            }
            .navigationTitle("회원가입")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(white: 0, opacity: 0.05))
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
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 70))
                            .padding()
                    }
                }
                .overlay(Circle().stroke(Color.blue, lineWidth: 4))
                
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
            TextField("이메일" ,text: $viewModel.email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.none)
            HStack {
                TextField(text: $viewModel.displayName, label: {
                    Text("닉네임")
                })
                TextField(text: $viewModel.userName, label: {
                    Text("성명")
                })
            }
            SecureField(text: $viewModel.password, label: {
                Text("비밀번호")
            })
            SecureField(text: $viewModel.passwordCheck, label: {
                Text("비밀번호 확인")
            })
        }
        .padding(12)
        .background(Color.white)
    }
    @ViewBuilder
    func signUpButtonView() -> some View {
        Button{
            
        } label: {
            Text("확인")
                .frame(maxWidth: .infinity)
                .font(.system(size: 18, weight: .none))
                .foregroundStyle(.background)
                .padding(15)
                .background(.blue, in: RoundedRectangle(cornerRadius: 15))
        }
    }
}

#Preview {
    RegistrationView(viewModel: .init())
}
