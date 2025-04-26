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
    
    enum Field {
        case email
        case displayName
        case password
        case passwordCheck
    }
    @FocusState private var focusFiled: Field?
    
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
                .overlay(Circle().stroke(.tint, lineWidth: 4))
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
                .submitLabel(.next)
                .focused($focusFiled, equals: .email)
                .onSubmit {
                    focusFiled = .displayName
                }
            
            TextField(text: $viewModel.displayName, label: {
                Text("이름")
            })
            .keyboardType(.default)
            .focused($focusFiled, equals: .displayName)
            .submitLabel(.next)
            .onSubmit {
                focusFiled = .password
            }
            
            SecureField(text: $viewModel.password, label: {
                Text("비밀번호")
            })
            .textContentType(.none)
            .focused($focusFiled, equals: .password)
            .submitLabel(.next)
            .onSubmit {
                focusFiled = .passwordCheck
            }
            
            SecureField(text: $viewModel.passwordCheck, label: {
                Text("비밀번호 확인")
            })
            .textContentType(.none)
            .focused($focusFiled, equals: .passwordCheck)
            .submitLabel(.done)
            .onSubmit {
                focusFiled = nil
            }
        }
        .padding(12)
        .overlay(content: {
            RoundedRectangle(cornerRadius: 20)
                .stroke(style: StrokeStyle(lineWidth: 0.8))
        })
        .onTapGesture {
            viewModel.statusMessage = ""
        }
    }
    
    @ViewBuilder
    func registrationButtonView() -> some View {
        Button{
            viewModel.registrationButtonTap()
        } label: {
            Text("가입하기")
                .frame(maxWidth: .infinity)
                .font(.system(size: 18, weight: .none))
                .foregroundStyle(.background)
                .padding(15)
                .background(.tint, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

#Preview {
    RegistrationView(viewModel: .init())
}
