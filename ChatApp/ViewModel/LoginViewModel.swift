//
//  LoginViewModel.swift
//  ChatApp
//
//  Created by window1 on 1/15/25.
//

import Foundation
import FirebaseAuth
import FirebaseStorage
import Combine
import UIKit

class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoginMode = false
    @Published var showAlert = false
    @Published var statusMessage = ""
    @Published var user: User?
    @Published var image: UIImage?
    
    private var cancellables = Set<AnyCancellable>()
    
    func loginButtonTap() {
        if validateInputFields(email: email, password: password) {
            if isLoginMode {
                login()
            } else {
                createAccount()
                
            }
        }
    }
    
    private func validateInputFields(email: String?, password: String?) -> Bool{
        guard let email = email, !email.isEmpty,
              let password = password, !password.isEmpty else {
            showAlert = true
            return false
        }
        showAlert = false
        return true
    }
    
    func profileButtonTap() {
        
    }
    
    /// 계정생성(Combine)
    func createAccount() {
        AuthManager.shared.registerUser(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                switch completion {
                case .failure(let error):
                    self?.statusMessage = self?.errorMessage(error: error.localizedDescription) ?? ""
                case .finished:
                    break;
                }
            } receiveValue: { authResult in
                self.statusMessage = authResult.user.uid
                self.uploadImage(uid: authResult.user.uid)
                
            }
            .store(in: &cancellables)
    }
    /// 로그인(Combine)
    func login() {
        AuthManager.shared.loginUser(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                switch completion {
                case .failure(let error):
                    self?.statusMessage = self?.errorMessage(error: error.localizedDescription) ?? ""
                case .finished:
                    break;
                }
            }, receiveValue: { [weak self] authDataResult in
                self?.statusMessage = authDataResult.user.uid
            })
            .store(in: &cancellables)
    }
    /// 이미지 업로드(Combine)
    func uploadImage(uid: String) {
        guard let imageData = self.image?.jpegData(compressionQuality: 0.2) else { return }
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        StorageManager.shared.uploadProfilePhoto(uid: uid, image: imageData, metaData: metadata)
            .flatMap({ metaData in
                StorageManager.shared.getDownloadURL(for: metadata.path ?? "")
            })
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    self.statusMessage = error.localizedDescription
                case .finished:
                    self.statusMessage = "Success upload Image"
                }
                
            }, receiveValue: { url in
                print("imagePath = \(url.absoluteString))")
            })
            .store(in: &cancellables)
    }
    
    
    func loginUser() {
        Auth.auth().signIn(withEmail: email, password: password) {
            result, error in
            if let error = error {
                print("Failed to login user:", error)
                self.statusMessage = "Failed to login user: \(self.errorMessage(error: error.localizedDescription))"
                return
            }
            print("Successfully logged user: \(result?.user.uid ?? "")")
            self.statusMessage = "Successfully logged in as user:\(result?.user.uid ?? "")"
            
        }
    }
    
    func createNewAccount() {
        Auth.auth().createUser(withEmail: email, password: password) {
            result, error in
            if let error = error {
                print("Failed to create user:", error)
                self.statusMessage = "Failed to Create user: \(self.errorMessage(error: error.localizedDescription))"
                return
            }
            print("Success created user: \(result?.user.uid ?? "")")
            self.statusMessage = "Successfully created user: \(result?.user.uid ?? "")"
            guard let uid = result?.user.uid else { return }
            self.uploadImageToStorage(uid: uid)
        }
    }
    
    /// 에러메시지 추출하기
    /// - Parameter error: 에러메시지 원본
    /// - Returns: 에러코드 및 중요 메시지
    func errorMessage(error: String) -> String {
        let pattern = #"Code=\d+\s".+\""#
        guard let range = error.range(of: pattern, options: .regularExpression) else {
            return error
        }
        return String(error[range])
    }
    
    /// 이미지 업로드
    func uploadImageToStorage(uid: String) {
        let ref = Storage.storage().reference(withPath: "images/\(uid)/profile.jpg")
        guard let imageData = self.image?.jpegData(compressionQuality: 0.2) else { return }
        ref.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                self.statusMessage = "Failed to push image to Storage: \(error)"
                print(error)
                return
            }
            ref.downloadURL { url, error in
                if let error = error {
                    self.statusMessage = "Failed to retrieve downloadURL: \(error)"
                    print(error)
                    return
                }
                self.statusMessage = "Successfully stored image with url: \(url?.absoluteString ?? "")"
                print(url?.absoluteString ?? "")
            }
            
        }
    }
}
