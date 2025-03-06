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
            VStack(spacing:15) {
                inputFieldView()
                Spacer()
                NavigationLink(destination: {
                    RegistrationView(viewModel: viewModel)
                }, label: {
                    HStack{
                        Text("계정이 없으신가요?")
                        Text("회원가입하기")
                            .bold()
                    }
                    .font(.subheadline)
                })
            }
            .padding()
            .navigationTitle("로그인" )
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(white: 0, opacity: 0.05))
            
        }
    }
    
    @ViewBuilder
    func inputFieldView() -> some View {
        Group {
            TextField("이메일", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.none)
            SecureField("비밀번호", text: $viewModel.password)
        }
        .padding(12)
        .overlay(content: {
            RoundedRectangle(cornerRadius: 20)
                .stroke(style: StrokeStyle(lineWidth: 0.8))
        })
        
        Button {
            viewModel.loginButtonTap()
            print(viewModel.isAuthenticated)
        } label: {
            Text("로그인")
                .frame(maxWidth: .infinity)
                .font(.system(size: 18, weight: .none))
                .foregroundStyle(.background)
                .padding(13)
                .background(.tint, in: RoundedRectangle(cornerRadius: 20))
        }
        .alert("이메일 혹은 비밀번호를 입력해주세요.", isPresented: $viewModel.showAlert, actions: {
            Button("확인", role: .cancel, action: {})
        })
        Text("\(viewModel.statusMessage)")
            .foregroundStyle(.gray)
    }
}

#Preview {
    LoginView(viewModel: .init())
}
