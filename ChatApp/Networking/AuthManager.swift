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
    @Published private(set) var id = Auth.auth().currentUser?.uid
    static let shared = AuthManager()
        
    func loginUser(email: String, password: String) -> Future<AuthDataResult, Error>{
        return Future { promise in
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                if let error = error {
                    promise(.failure(error))
                } else if let result = result {
                    promise(.success(result))
                    self.id = result.user.uid
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
                    self.id = result.user.uid
                }
            }
        }
    }
    
    func loginUser(email: String, password: String) async throws -> AuthDataResult {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        id = result.user.uid
        return result
    }
    
    func regiserUser(email: String, password: String) async throws -> AuthDataResult {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        id = result.user.uid
        return result
    }
    
    func signOut() {
        try? Auth.auth().signOut()
    }
}
