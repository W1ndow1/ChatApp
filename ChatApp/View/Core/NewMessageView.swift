//
//  NewMessageView.swift
//  ChatApp
//
//  Created by window1 on 2/8/25.
//

import SwiftUI
import SDWebImageSwiftUI

struct NewMessageView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var viewModel = NewMessageViewModel()
    @State var searchText = ""
    @State var selectedItems: Set<ChatUser> = []
    
    var didSelectNewUser: (Set<ChatUser>) -> ()
    
    var body: some View {
        NavigationStack {
            Group {
                TextField(" 🔎검색 ", text: $searchText)
                    .frame(height: 40)
                    .border(Color.gray, width: 0.5)
            }
            .padding(10)
            
            ScrollView{
                ForEach(viewModel.users.filter { user in
                    searchText.isEmpty ||
                    user.displayName.contains(searchText) ||
                    user.email.contains(searchText)}) { data in
                    NewMessagevViewRow(user: data, selectedItems: $selectedItems)
                }
            }
            .navigationTitle("대화상대 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button{
                        dismiss()
                    }label: {
                        Text("취소")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button{
                        didSelectNewUser(selectedItems)
                        dismiss()
                    }label: {
                        Text("확인")
                    }
                    .disabled(selectedItems.isEmpty)
                }
            }
            .onAppear() {
            }
        }
    }
}


#Preview {
    NewMessageView(didSelectNewUser: {
        _ in
    })
}


struct NewMessagevViewRow: View {
    @State var checkedRow = false
    let user: ChatUser
    @Binding var selectedItems: Set<ChatUser>
    
    var body: some View {
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
            Button {
                checkedRow.toggle()
                if checkedRow {
                    selectedItems.insert(user)
                } else {
                    selectedItems.remove(user)
                }
            }label: {
                Image(systemName: checkedRow ? "checkmark.circle.fill" : "checkmark.circle" )
                    .font(.system(size: 20, weight: .light))
                    .tint(.primary)
            }
        }
        .padding(.horizontal, 15)
        Divider()
        
    }
}
