//
//  User.swift
//  ChatApp
//
//  Created by window1 on 1/12/25.
//

import Foundation

struct ChatUser: Identifiable, Codable, Hashable {
    var id: String { uid }
    var uid: String
    var email: String = ""
    var profileImageURL: String = ""
    var displayName: String = ""
}
