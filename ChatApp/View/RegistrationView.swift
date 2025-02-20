//
//  RegistrationView.swift
//  ChatApp
//
//  Created by window1 on 2/10/25.
//

import SwiftUI
import PhotosUI

struct RegistrationView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: LoginViewModel
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 15) {
                profileImageView()
                inputFiledView()
                registrationButtonView()
                   
                Text("\(viewModel.statusMessage)")
                    .font(.subheadline)
                    .foregroundStyle(Color(.systemPink))
                Spacer()
                Button {
                    dismiss()
                }label: {
                    HStack {
                        Text("이미 계정이 있으신가요?")
                        Text("로그인하기")
                            .bold()
                    }
                    .font(.subheadline)
                }
            }
            .padding()
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
            TextField(text: $viewModel.displayName, label: {
                Text("닉네임")
            })
            SecureField(text: $viewModel.password, label: {
                Text("비밀번호")
            })
            SecureField(text: $viewModel.passwordCheck, label: {
                Text("비밀번호 확인")
            })
        }
        .onTapGesture {
            viewModel.statusMessage = ""
        }
        .padding(12)
    }
    @ViewBuilder
    func registrationButtonView() -> some View {
        Button{
            viewModel.isLoginMode = false
            viewModel.registrationButtonTap()
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
