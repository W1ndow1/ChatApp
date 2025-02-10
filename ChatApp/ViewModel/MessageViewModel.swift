//
//  MessageViewModel.swift
//  ChatApp
//
//  Created by window1 on 2/5/25.
//

import Foundation
import Combine
import UIKit

class MessageViewModel: ObservableObject {
    @Published var errorMessage = ""
    @Published var currentUser: ChatUser?
    @Published var profileImage: UIImage?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        fetchCurrentUser()
    }
    
    private func fetchCurrentUser() {
        guard let uid = AuthManager.shared.id else { return }
        DatabaseManager.shared.collectionUsers(uid: uid)
            .handleEvents(receiveOutput:  { user in
                guard let imageURL = URL(string: user.profileImageURL) else { return }
                Task {
                    await self.fetchImage(url: imageURL)
                }
            })
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let failure) = completion {
                    self?.errorMessage = failure.localizedDescription
                }
            }, receiveValue: { user in
                self.currentUser = user
            })
            .store(in: &cancellables)
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

