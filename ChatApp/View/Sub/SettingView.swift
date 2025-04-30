//
//  SettingView.swift
//  ChatApp
//
//  Created by window1 on 2/4/25.
//

import SwiftUI
import SDWebImageSwiftUI

struct SettingView: View {
    @EnvironmentObject var loginViewModel: LoginViewModel
    @StateObject var viewModel = SettingViewModel()
    @State private var showingAlert = false
    
    var body: some View {
        List {
            userInfoSection()
            accountSection()
        }
        .onAppear(){
            viewModel.fetchCurrentUser()
        }
        .fullScreenCover(isPresented: $viewModel.isUserCurrentlyLoggedOut, onDismiss: nil) {
            HomeTabView()
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    func userInfoSection() -> some View {
        Section {
            HStack {
                if (viewModel.currentUser?.profileImageURL != nil) {
                    WebImage(url: URL(string: viewModel.currentUser?.profileImageURL ?? ""))
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                        .font(.system(size: 50))
                        .overlay(RoundedRectangle(cornerRadius: 44).stroke(.opacity(0.3), lineWidth: 1))
                } else {
                    Text(viewModel.currentUser?.displayName.prefix(2) ?? "")
                        .font(.system(size: 35, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.gray)
                        .clipShape(/*@START_MENU_TOKEN@*/Circle()/*@END_MENU_TOKEN@*/)
                }
                VStack(alignment:.leading) {
                    Text(viewModel.currentUser?.displayName ?? "")
                        .font(.system(size: 18, weight: .semibold))
                    Text(viewModel.currentUser?.email ?? "")
                        .font(.system(size: 13))
                        .foregroundStyle(.tint)
                }
            }
        }
    }
    
    @ViewBuilder
    func accountSection() -> some View {
        Section("계정") {
            NavigationLink {
                EditUserInfoView(svm: viewModel)
            } label: {
                Text("사용자 정보수정")
            }
            
            Button {
                showingAlert = true
            } label: {
                Text("로그아웃")
            }
            .confirmationDialog("로그아웃",
                                isPresented: $showingAlert,
                                titleVisibility: .visible) {
                Button("확인", role: .destructive) {
                    loginViewModel.logout()
                }
                Button("취소", role: .cancel) {
                }
            } message: {
                Text("로그아웃하시겠습니까?")
            }
        }
    }
}

#Preview {
    SettingView()
        .environmentObject(LoginViewModel())
}

