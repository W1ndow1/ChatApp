//
//  DatabaseManager.swift
//  ChatApp
//
//  Created by window1 on 1/25/25.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreCombineSwift
import Combine


class DatabaseManager: NSObject {
    
    static let shared = DatabaseManager()
    
    let db = Firestore.firestore()
    let usersPath: String = "users"
    
    
    func storeUserInformation(userData: [String: Any], uid: String) -> Future<Bool, Error>{
        return Future<Bool, Error> { promise in
            self.db.collection(self.usersPath).document(uid).setData(userData) { error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(true))
                }
            }
        }
    }
    
    func storeUserInformation(userData: ChatUser, uid: String) -> Future<Bool, Error>{
        return Future<Bool, Error> { promise in
            do {
                try self.db.collection(self.usersPath).document(uid).setData(from: userData) { error in
                    if let error = error {
                        promise(.failure(error))
                    } else {
                        promise(.success(true))
                    }
                }
            } catch {
                promise(.failure(error))
            }
        }
    }
    
    func collectionUsers(uid id: String) -> AnyPublisher<ChatUser, Error> {
        db.collection(self.usersPath).document(id).getDocument()
            .tryMap { try $0.data(as: ChatUser.self)}
            .eraseToAnyPublisher()
    }
    
    func collectionAllUsers() -> AnyPublisher<[ChatUser], Error> {
        return Future { promise in
            self.db.collection(self.usersPath).getDocuments() { snapshot, error in
                if let error = error {
                    promise(.failure(error))
                } else if let documents = snapshot?.documents {
                    do {
                        let users = try documents.map({ try $0.data(as: ChatUser.self)})
                        promise(.success(users))
                    } catch {
                        promise(.failure(error))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
