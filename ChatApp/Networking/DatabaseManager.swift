//
//  DatabaseManager.swift
//  ChatApp
//
//  Created by window1 on 1/25/25.
//

import Foundation
import FirebaseFirestore


class DatabaseManager: NSObject {
    
    static let shared = DatabaseManager()
    
    let db = Firestore.firestore()
    
    
}
