//
//  User.swift
//  ChatApp
//
//  Created by window1 on 1/12/25.
//

import Foundation

struct ChatUser: Codable, Identifiable {
    var id: String { uid }
    
    var uid: String
    var email: String = ""
    var profileImageURL: String = ""
    //var displayName: String = ""
    //var createOn:Date = Date()
}
