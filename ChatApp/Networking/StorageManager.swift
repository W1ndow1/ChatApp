//
//  StorageManager.swift
//  ChatApp
//
//  Created by window1 on 1/20/25.
//

import Foundation
import Combine
import FirebaseStorage

class StorageManager {
    
    static let shared = StorageManager()
    
    let storage = Storage.storage().reference()
    
    func uploadProfilePhoto(uid: String, image: Data, metaData: StorageMetadata) -> Future<StorageMetadata, Error> {
        return Future<StorageMetadata, Error> { promise in
            let ref = self.storage.storage.reference(withPath: "images/\(uid).jpeg")
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
            let ref = self.storage.storage.reference(withPath: id)
            ref.downloadURL { url, error in
                if let error = error {
                    promise(.failure(error))
                } else if let url = url {
                    promise(.success(url))
                }
            }
        }
    }
}

