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
    @State var selectedTab = 1
    
    var body: some View {
        if viewModel.isAuthenticated {
            Group {
                TabView(selection: $selectedTab) {
                    FriendListView()
                        .tabItem { Label("친구", systemImage: "person") }
                        .environmentObject(viewModel)
                        .tag(0)
                    MessageListView()
                        .tabItem { Label("메시지", systemImage: "message") }
                        .environmentObject(viewModel)
                        .tag(1)
                        
                }
            }
            .onAppear() {
                
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
