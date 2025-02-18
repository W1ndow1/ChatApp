//
//  NewMessageViewModel.swift
//  ChatApp
//
//  Created by window1 on 2/9/25.
//

import Foundation
import Combine
import UIKit

class NewMessageViewModel: ObservableObject {
    @Published var users: [ChatUser] = []
    @Published var errerMessage = ""
    @Published var profileImage: UIImage?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        fetchAllUsers()
    }
    
    private func fetchAllUsers() {
        DatabaseManager.shared.collectionAllUsers()
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    self.errerMessage = "Error fetching users: \(error)"
                    print("Error fetching users: \(error)")
                }
            }, receiveValue: { [weak self] users in
                self?.users = users
                self?.errerMessage = "Fetched users Successfully"
            })
            .store(in: &cancellables)
    }
    
    private func fetchAllUsers() async throws -> [ChatUser] {
        let snapshot = try await DatabaseManager.shared.db.collection("users").getDocuments()
        return try snapshot.documents.map({ try $0.data(as: ChatUser.self)})
    }
    
    private func fetchImage(url: URL) async {
        do {
            let request = URLRequest(url: url)
            let (data, _) = try await URLSession.shared.data(for: request)
            if let uiimage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.profileImage = uiimage
                }
            }
        } catch {
            print("Failed to load Image", error)
        }
    }
}
