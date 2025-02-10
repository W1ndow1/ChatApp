//
//  NewMessageView.swift
//  ChatApp
//
//  Created by window1 on 2/8/25.
//

import SwiftUI

struct NewMessageView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var viewModel = NewMessageViewModel()
    @State var searhText = ""
    @State private var profileImage: UIImage? = nil
    
    var body: some View {
        NavigationStack {
            Group {
                TextField(" 🔎검색 ", text: $searhText)
                    .frame(height: 40)
                    .border(Color.gray, width: 0.5)
            }
            .padding(10)
                
            ScrollView {
                ForEach(viewModel.users) { num in
                    NewMessagevViewRow(user: num)
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
                    }label: {
                        Text("확인")
                    }
                }
            }
            .onAppear() {
            }
        }
    }
    
    
}

#Preview {
    NewMessageView()
}


struct NewMessagevViewRow: View {
    let user: ChatUser
       @State private var profileImage: UIImage? = nil

       var body: some View {
           HStack {
               if let profileImage = profileImage {
                   Image(uiImage: profileImage)
                       .resizable()
                       .scaledToFill()
                       .frame(width: 50, height: 50)
                       .clipShape(Circle())
               } else {
                   ProgressView()
                       .frame(width: 50, height: 50)
                       .task {
                           await loadImage()
                       }
               }
               Text(user.email)
               Spacer()
           }
           .padding()
       }
    
    private func loadImage() async {
        do {
            profileImage = try await fetchImage(url: user.profileImageURL)
        } catch {
            print("Failed to load image:", error)
        }
    }
    
    private func fetchImage(url: String) async throws -> UIImage {
        guard let url = URL(string: url) else { throw URLError(.badURL) }
        return try await StorageManager.shared.getImage(url: url)
    }
}
