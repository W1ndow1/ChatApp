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
    @Published var showAlert = false
    @Published var statusMessage = ""
    @Published var image: UIImage?
    @Published var isAuthenticated = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        isAuthenticated = (AuthManager.shared.id != nil)
    }
    
    func loginButtonTap() {
        if validateInputFields(email: email, password: password) {
            login()
        } else {
            statusMessage = "비어 있는 정보가 있습니다."
        }
    }
    
    func registrationButtonTap() {
        guard passwardCheck(password: password, passwordcCheck: passwordCheck) else {
            return statusMessage = "비밀번호가 일치하지 않습니다."
        }
        if validateInputFields(email: email, 
                               password: password,
                               displayName: displayName) {
            createAccount()
        } else{
            statusMessage = "비어 있는 정보가 있습니다."
        }
    }
    
    private func passwardCheck(password: String, passwordcCheck: String) -> Bool {
        return password == passwordcCheck
    }
    
    private func validateInputFields(email: String?, password: String?) -> Bool{
        guard let email = email, !email.isEmpty,
              let password = password, !password.isEmpty
        else {
            showAlert = true
            return false
        }
        showAlert = false
        return true
    }
    
    private func validateInputFields(email: String?, password: String?, displayName: String?) -> Bool{
        guard let email = email, !email.isEmpty,
              let password = password, !password.isEmpty,
              let displayName = displayName, !displayName.isEmpty
        else {
            showAlert = true
            return false
        }
        showAlert = false
        return true
    }
    
    //로그인
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
    
    //로그아웃
    func logout() {
        AuthManager.shared.signOut()
        resetFields()
        isAuthenticated = false
    }
    
    //계정생성
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
    
    //이미지 업로드
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
                self.storeUserInfo(url: url)
            })
            .store(in: &cancellables)
    }
    
    func storeUserInfo(url: URL) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let userData = ChatUser(uid: uid, 
                                email: self.email,
                                profileImageURL: url.absoluteString,
                                displayName: displayName)
        DatabaseManager.shared.storeUserInformation(userData: userData, uid: uid)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    self.statusMessage = error.localizedDescription
                case .finished:
                    self.statusMessage = "Success upload userData"
                }
                
            }, receiveValue: { _ in
                
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
    
    
    func resetFields() {
        email = ""
        password = ""
        passwordCheck = ""
        displayName = ""
        userName = ""
        showAlert = false
        statusMessage = ""
        image = nil
    }
    

    func editUserInfoButtonTap() {
        guard let userId = AuthManager.shared.id else { return }
        guard !displayName.isEmpty else {
            self.statusMessage = "변경할 닉네임 이름을 입력해주세요"
            return }
        DatabaseManager.shared.updateUserDisplayName(userId: userId, displayName: displayName)
            //이미지 업로드
            .flatMap { succss -> AnyPublisher<Bool, Error> in
                guard succss else {
                    return Just(false).setFailureType(to: Error.self).eraseToAnyPublisher()
                }
                if let image = self.image {
                    return StorageManager.shared.uploadProfileImage(userId: userId, image: image)
                        .flatMap { url in
                            DatabaseManager.shared.updateUserProfileImageURL(userId: userId, imageURL: url)
                        }
                        .eraseToAnyPublisher()
                } else {
                    return Just(true).setFailureType(to: Error.self).eraseToAnyPublisher()
                }
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print("Error update displayName: \(error)")
                    self.statusMessage = "수정에 실패 했습니다."
                case .finished:
                    break
                }
        
            }, receiveValue: { result in
                self.statusMessage = result ? "수정되었습니다." : "수정실패"
            })
            .store(in: &cancellables)
    }
    
    
}
