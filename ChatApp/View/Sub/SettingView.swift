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
    @State private var showingClearCacheAlert = false
    @State private var cacheSize: Double = 0.0
    
    var body: some View {
        List {
            userInfoSection()
            accountSection()
            storageSection()
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
                Button("취소", role: .cancel) { }
            } message: {
                Text("로그아웃하시겠습니까?")
            }
        }
    }
    @ViewBuilder
    func storageSection() -> some View {
        Section("저장공간") {
            Button {
                showingClearCacheAlert = true
            }label: {
                Text("현재 캐시크기: \(String(format: "%.2f MB", cacheSize))")
            }
            .confirmationDialog("캐시삭제", isPresented: $showingClearCacheAlert, titleVisibility: .visible) {
                Button("확인", role: .destructive) {
                    ImageCacheManager.shared.clearAllCache()
                    cacheSize = Double(ImageCacheManager.shared.totalCacheSize()) / 1024 / 1024
                }
                Button("취소", role: .cancel) { }
            }
        }
        .onAppear {
            cacheSize = Double(ImageCacheManager.shared.totalCacheSize()) / 1024 / 1024
        }
    }
}

#Preview {
    SettingView()
        .environmentObject(LoginViewModel())
}

