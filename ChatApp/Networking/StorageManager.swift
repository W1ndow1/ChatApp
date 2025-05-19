//
//  StorageManager.swift
//  ChatApp
//
//  Created by window1 on 1/20/25.
//

import Foundation
import Combine
import FirebaseStorage
import UIKit

class StorageManager {
    static let shared = StorageManager()
    let storage = Storage.storage()
    
    func uploadProfilePhoto(uid: String, image: Data, metaData: StorageMetadata) -> Future<StorageMetadata, Error> {
        return Future<StorageMetadata, Error> { promise in
            let ref = self.storage.reference(withPath: "images/users/\(uid).jpeg")
            ref.putData(image, metadata: metaData) { metaData, error in
                if let error = error {
                    promise(.failure(error))
                } else if let metaData = metaData {
                    promise(.success(metaData))
                }
            }
        }
    }
    
    func getDownloadURL(for id: String) -> Future<URL, Error> {
        return Future { promise in
            let ref = self.storage.reference(withPath: id)
            ref.downloadURL { url, error in
                if let error = error {
                    promise(.failure(error))
                } else if let url = url {
                    promise(.success(url))
                }
            }
        }
    }
    
    func uploadProfileImage(userId: String, image: UIImage) -> AnyPublisher<String, Error> {
        Future { promise in
            let storageRef = self.storage.reference().child("images/users/\(userId).jpeg")
            let resizeImage = image.resizeMaintainningRatio(toWidth: 300)
            guard let imageData = resizeImage.jpegData(compressionQuality: 0.5) else { return }
            let meta = StorageMetadata()
            meta.contentType = "image/jpeg"
            storageRef.putData(imageData, metadata: meta) { mataData, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                storageRef.downloadURL(completion: { url, error in
                    if let error = error {
                        promise(.failure(error))
                    } else if let url = url {
                        promise(.success(url.absoluteString))
                    }
                })
            }
        }
        .eraseToAnyPublisher()
    }
    
    func getImage(url: URL) async throws -> UIImage {
        let request = URLRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let image = UIImage(data: data) else { throw URLError(.badServerResponse) }
        return image
    }
    
    func uploadChatRoomImage(image: Data, chatRoomId: String) async throws -> URL {
        let storageRef = self.storage.reference()
        let imageRef = storageRef.child("images/room/\(chatRoomId)/\(UUID().uuidString).jpeg")
        let metaData = StorageMetadata()
        metaData.contentType = "image/jpeg"
        _ = try await imageRef.putDataAsync(image, metadata: metaData)
        return try await imageRef.downloadURL()
    }
}

