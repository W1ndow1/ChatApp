//
//  ContentView.swift
//  ChatApp
//
//  Created by window1 on 1/11/25.
//

import SwiftUI
import PhotosUI

struct LoginView: View {
    @ObservedObject var viewModel: LoginViewModel
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Picker(selection: $viewModel.isLoginMode, label: Text("PickerHERE")) {
                        Text("로그인")
                            .tag(true)
                        Text("계정생성")
                            .tag(false)
                    }
                    .pickerStyle(.palette)
                    .onChange(of: viewModel.isLoginMode, { newValue, oldValue in
                        viewModel.email = ""
                        viewModel.password = ""
                    })
                    
                    profileImageView()
                    
                    Group {
                        TextField("이메일", text: $viewModel.email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.none)
                        SecureField("비밀번호", text: $viewModel.password)
                    }
                    .padding(12)
                    .background(Color.white)
                    
                    Button {
                        viewModel.loginButtonTap()
                        print(viewModel.isAuthenticated)
                    } label: {
                        Text(viewModel.isLoginMode ? "로그인" : "가입하기")
                            .frame(maxWidth: .infinity)
                            .font(.system(size: 18, weight: .none))
                            .foregroundStyle(.background)
                            .padding(13)
                            .background(.blue, in: RoundedRectangle(cornerRadius: 15))
                    }
                    .alert("이메일 혹은 비밀번호를 입력해주세요.", isPresented: $viewModel.showAlert, actions: {
                        Button("확인", role: .cancel, action: {})
                    })
                    
                    Text("\(viewModel.statusMessage)")
                        .foregroundStyle(.gray)
                }
                .padding()
            }
            .navigationTitle(viewModel.isLoginMode ? "로그인" : "가입하기")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(white: 0, opacity: 0.05))
            NavigationLink(destination: {
                RegistrationView(viewModel: viewModel)
            }, label: {
                Text("회원가입하기")
            })
        }
    }
    
    @ViewBuilder
    func profileImageView() -> some View {
        if !viewModel.isLoginMode {
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
    }
}

#Preview {
    LoginView(viewModel: .init())
}
