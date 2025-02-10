//
//  SettingView.swift
//  ChatApp
//
//  Created by window1 on 2/4/25.
//

import SwiftUI


struct SettingView: View {
    @EnvironmentObject var envirModel: LoginViewModel
    @StateObject var setModel = SettingViewModel()
    @State private var showingAlert = false
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("CG")
                        .font(.system(size: 35, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 70, height: 70)
                        .background(Color.gray)
                        .clipShape(/*@START_MENU_TOKEN@*/Circle()/*@END_MENU_TOKEN@*/)
                    VStack(alignment:.leading) {
                        Text("Cookie Gokmul")
                            .font(.system(size: 18, weight: .semibold))
                        Text("gokmulCookie@gmail.com")
                            .font(.system(size: 13))
                    }
                }
            }
            Section("계정") {
                Button {
                } label: {
                    Text("사용자 정보 수정")
                        .foregroundStyle(.black)
                }
                
                Button {
                    showingAlert = true
                } label: {
                    Text("로그아웃")
                        .foregroundStyle(.black)
                }
                .confirmationDialog("로그아웃", isPresented: $showingAlert, titleVisibility: .visible) {
                    Button("확인", role: .destructive) {
                        setModel.handleSignOut()
                        envirModel.isAuthenticated = false
                    }
                    Button("취소", role: .cancel) {
                    }
                } message: {
                    Text("로그아웃하시겠습니까?")
                }
            }
        }
        .fullScreenCover(isPresented: $setModel.isUserCurrentlyLoggedOut, onDismiss: nil) {
            HomeTabView()
        }
    }
}

#Preview {
    SettingView()
        .environmentObject(LoginViewModel())
}
