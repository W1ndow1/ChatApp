//
//  User.swift
//  ChatApp
//
//  Created by window1 on 1/12/25.
//

import Foundation

struct ChatUser: Identifiable {
    var id: String
    var email: String = ""
    var displayName: String = ""
    var userName: String = ""
    var profileImagePath: String = ""
    var createOn:Date = Date()
}
