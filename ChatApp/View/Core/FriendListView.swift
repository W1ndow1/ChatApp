//
//  FriendListView.swift
//  ChatApp
//
//  Created by window1 on 2/4/25.
//

import SwiftUI

struct FriendListView: View {
    @State var txtFiled: String = ""
    var body: some View {
        HStack {
            Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
            Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
            TextField(text: $txtFiled, label: {
                
            })
        }
    }
}

#Preview {
    FriendListView()
}
