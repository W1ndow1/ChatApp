//
//  TabView.swift
//  ChatApp
//
//  Created by window1 on 2/4/25.
//

import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject var viewModel: LoginViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        if viewModel.isAuthenticated {
            Group {
                TabView {
                    FriendListView()
                        .tabItem { Label("친구", systemImage: "person") }
                        .environmentObject(viewModel)
                    MessageListView()
                        .tabItem { Label("메시지", systemImage: "message") }
                        .environmentObject(viewModel)
                }
            }
        } else {
            LoginView(viewModel: viewModel)
        }
        
    }
}

#Preview {
    HomeTabView()
        .environmentObject(LoginViewModel())
}
