//
//  FriendListView.swift
//  ChatApp
//
//  Created by window1 on 2/4/25.
//

import SwiftUI
import SDWebImageSwiftUI

struct FriendListView: View {
    @StateObject private var viewModel = FriendListViewModel()
    @State private var searchText = ""
    @State private var showSearchbar = false
    @State private var selectedUser: ChatUser? = nil
    @State private var selectedUserData: Set<ChatUser>?
    @State private var navigationChatLogView = false
    @FocusState private var isTextFieldFocused: Bool
    
    
    var body: some View {
        NavigationStack {
            VStack {
                if showSearchbar {
                    searchBar()
                }
                friendList()
                    .navigationDestination(isPresented: $navigationChatLogView) {
                        ChatLogView(userData: selectedUserData)
                    }
            }
            .toolbar {
                navigationBarContent()
            }
        }
    }
    @ViewBuilder
    func userRow(user: ChatUser) -> some View {
        Button {
            selectedUser = user
        } label: {
            HStack {
                WebImage(url: URL(string: user.profileImageURL))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                
                VStack(alignment: .leading) {
                    Text(user.displayName)
                    Text(user.email)
                        .font(.system(size: 13, weight: .light))
                }
                Spacer()
            }
            .padding(.horizontal, 15)
        }
        .tint(.primary)
    }
    
    @ViewBuilder
    func friendList() -> some View {
        ScrollView {
            //CurrentUser Section
            if let currentUser = viewModel.users.first(where: { $0.uid == AuthManager.shared.id }) {
                userRow(user: currentUser)
                Divider()
            }
            //OtherUser
            Section(header: sectionHeader()) {
                let users = viewModel.users.filter({$0.uid != AuthManager.shared.id})
                ForEach(users.filter { user in
                    searchText.isEmpty ||
                    user.displayName.contains(searchText) ||
                    user.email.contains(searchText) }) { user in
                        userRow(user: user)
                        Divider()
                    }
            }
        }
        .onTapGesture { self.hideKeyboard() }
        .fullScreenCover(item: $selectedUser) { user in
            ProfileView(user: user, startChatting: { user in
                self.navigationChatLogView.toggle()
                self.selectedUserData = user
            })
        }
    }
    @ViewBuilder
    func sectionHeader() -> some View {
        HStack {
            Text("친구")
                .font(.system(size: 13))
            Spacer()
        }
        .padding(.horizontal, 15)
    }
    
    
    @ViewBuilder
    func searchBar() -> some View {
        TextField(text: $searchText, label: {
            Text("검색어 입력")
        })
        .textFieldStyle(.roundedBorder)
        .focused($isTextFieldFocused)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }
    
    @ToolbarContentBuilder
    func navigationBarContent() -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Text("친구")
                .font(.system(size: 22, weight: .light))
                .padding(.trailing, 5)
        }
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 3) {
                Button {
                    withAnimation(.easeInOut(duration:0.1)){
                        showSearchbar.toggle()
                        if showSearchbar {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                isTextFieldFocused = true
                            }
                        }
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color(.label))
                }
                
                NavigationLink {
                    SettingView()
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(Color(.label))
                }
            }
        }
    }
    
    func makeUserArray(user: ChatUser) -> Set<ChatUser> {
        var users = Set<ChatUser>()
        users.insert(user)
        return users
    }
}



#Preview {
    FriendListView()
}


