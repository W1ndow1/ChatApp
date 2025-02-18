//
//  ChatLogView.swift
//  ChatApp
//
//  Created by window1 on 2/12/25.
//

import SwiftUI

struct ChatLogView: View {
    @ObservedObject var viewModel: ChatLogViewModel
    @State var navigationTitle = ""
    @State var enterButtonText = "#"
    let userData: Set<ChatUser>?
    
    init(userData: Set<ChatUser>?) {
        self.userData = userData
        self.viewModel = .init(userData: userData)
        
    }
    
    var body: some View {
        ZStack {
            chatBubbleRow()
            .navigationTitle("\(navigationTitle)")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                titleLengthCheck()
            }
        }
    }
    
    @ViewBuilder
    private func chatBubbleRow() -> some View {
        ScrollView {
            ForEach(viewModel.chatMessages) { num in
                HStack {
                    Spacer()
                    HStack {
                        Text(num.text)
                            .foregroundStyle(Color.white)
                            .padding()
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .frame(minWidth: 30 ,maxWidth: 230, alignment: .trailing)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding([.top, .horizontal], 8)
            }
            HStack { Spacer() }
        }
        .background(Color(white: 0.3, opacity: 0.1))
        .safeAreaInset(edge: .bottom, content: viewBottom)
    }
    
    @ViewBuilder
    private func viewBottom() -> some View {
        HStack {
            Button{
                
            } label: {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundStyle(Color.primary)
            }
            TextField("메시지", text: $viewModel.chatText)
                .foregroundStyle(Color.primary)
                .onChange(of: viewModel.chatText, { old, new in
                    enterButtonText = viewModel.chatText.count > 0 ? "⇧" : "#"
                })
               
            Button {
                viewModel.sendMessage()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .frame(width: 30, height: 30)
                    Text(enterButtonText)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(Color.white)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}


#Preview {
    ChatLogView(userData: .none)

}

extension ChatLogView {
    func titleLengthCheck() {
        guard let userData = userData else { return }
        if userData.count < 4 {
            navigationTitle = userData.map({ $0.displayName }).joined(separator: ", ")
        } else {
            navigationTitle = userData.prefix(3).map({ $0.displayName }).joined(separator: ", ") + "..."
        }
    }
    
    func setToID() {
        guard let userData = userData else { return }
        
    }
}
