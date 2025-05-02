//
//  ContentView.swift
//  ChatApp
//
//  Created by window1 on 1/11/25.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: LoginViewModel
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email
        case password
    }
    
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
        .customAlert(title: "확인",
                     message: "이메일 혹은 비밀번호를 입력해주세요.",
                     isPresented: $viewModel.showAlert,
                     actions: [AlertAction(title: "확인", role: .none, action: {})])
    }
    
    @ViewBuilder
    func inputFieldView() -> some View {
        Group {
            TextField("이메일", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.none)
                .submitLabel(.next)
                .focused($focusedField, equals: .email)
                .onSubmit {
                    focusedField = .password
                }
            SecureField("비밀번호", text: $viewModel.password)
                .focused($focusedField, equals: .password)
                .submitLabel(.done)
                .onSubmit {
                    focusedField = nil
                    viewModel.loginButtonTap()
                }
        }
        .padding(12)
        .overlay(content: {
            RoundedRectangle(cornerRadius: 20)
                .stroke(style: StrokeStyle(lineWidth: 0.8))
        })
        
        Button {
            viewModel.loginButtonTap()
        } label: {
            Text("로그인")
                .frame(maxWidth: .infinity)
                .font(.system(size: 18, weight: .none))
                .foregroundStyle(.background)
                .padding(13)
                .background(.tint, in: RoundedRectangle(cornerRadius: 20))
        }
        Text("\(viewModel.statusMessage)")
            .foregroundStyle(.gray)
    }
}

#Preview {
    let viewModel = LoginViewModel()
    viewModel.email = "Blue1423@gmail.com" // 초기값 테스트
    viewModel.password = "1234567"
    return LoginView(viewModel: viewModel)

}
