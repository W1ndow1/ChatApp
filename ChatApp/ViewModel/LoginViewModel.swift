//
//  LoginViewModel.swift
//  ChatApp
//
//  Created by window1 on 1/15/25.
//

import Foundation
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
import Combine
import UIKit
import SwiftUI

class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var passwordCheck = ""
    @Published var displayName = ""
    @Published var userName = ""
    @Published var isLoginMode = false
    @Published var showAlert = false
    @Published var statusMessage = ""
    @Published var image: UIImage?
    @Published var isAuthenticated = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.isAuthenticated = AuthManager.shared.id != nil
    }
    
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
                self.isAuthenticated = true
                
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
                self?.statusMessage = "User Uid : \(authDataResult.user.uid)"
                self?.isAuthenticated = true
                
                
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
                self.storeUserInfomation(imageProfileURL: url)
            })
            .store(in: &cancellables)
    }
    
    func storeUserInfo(url: URL) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let userData = [
            "email": self.email,
            "uid": uid,
            "profileImageURL": url.absoluteString
        ]
        let userData2 = ChatUser(uid: uid, email: self.email, profileImageURL: url.absoluteString)
        DatabaseManager.shared.storeUserInformation(userData: userData2, uid: uid)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    self.statusMessage = error.localizedDescription
                case .finished:
                    self.statusMessage = "Success upload userData"
                }
                
            }, receiveValue: {_ in
                
            })
            .store(in: &cancellables)
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
    
    
    func storeUserInfomation(imageProfileURL: URL) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let userData = [
            "email": self.email,
            "uid": uid,
            "profileImageURL": imageProfileURL.absoluteString
        ]
        Firestore.firestore().collection("users")
            .document(uid).setData(userData) { error in
                if let error = error {
                    print(error)
                    self.statusMessage = error.localizedDescription
                    return
                }
                print("Success upload userData")
            }
    }
}
