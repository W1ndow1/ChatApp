//
//  AuthManager.swift
//  ChatApp
//
//  Created by window1 on 1/18/25.
//

import Foundation
import Combine
import FirebaseAuth

class AuthManager: ObservableObject {
    
    static let shared = AuthManager()
    
    var id: String? { Auth.auth().currentUser?.uid }
    
    func loginUser(email: String, password: String) -> Future<AuthDataResult, Error>{
        return Future { promise in
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                if let error = error {
                    promise(.failure(error))
                } else if let result = result {
                    promise(.success(result))
                }
            }
        }
    }
    
    
    func registerUser(email: String, password: String) -> Future<AuthDataResult, Error>{
        return Future { promise in
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                if let error = error {
                    promise(.failure(error))
                } else if let result = result {
                    promise(.success(result))
                }
            }
        }
    }
    
    func logoutUser() {
        try? Auth.auth().signOut()
    }
}
