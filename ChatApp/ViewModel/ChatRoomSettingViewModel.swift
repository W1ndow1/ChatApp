//
//  ChatRoomSettingViewModel.swift
//  ChatApp
//
//  Created by window1 on 6/6/25.
//

import Foundation
import SwiftUI

class ChatRoomSettingViewModel: ObservableObject {
    
    @Published var selectColor: Color = .whiteBlack
    
    
    func fetchChatRoomBackGroundColor(userId: String, chatRoomId: String) async {
        let settingRef = DatabaseManager.shared.db.collection("roomSetting").document(userId)
            .collection("roomId").document(chatRoomId)
        do {
            let snapshot = try await settingRef.getDocument()
            let data = snapshot.data()
            let argbString = data?["backGroundColor"] as? String
            let color = Color(hex: argbString ?? "#FFFFFF") ?? .whiteBlack
            
            await MainActor.run(body: {
                selectColor = color
            })
        } catch {
            AppError.shared.show(
                """
                데이터를 가져오는데 실패했습니다.
                \(error.localizedDescription)
                """,
                type: .server)
        }
    }
    
    func updateChatRoomBackGroundColor(userId: String, chatRoomId: String,  color: String) async {
        let settingRef = DatabaseManager.shared.db.collection("roomSetting").document(userId)
            .collection("roomId").document(chatRoomId)
        do {
            try await settingRef.setData(["backGroundColor" : color], merge: true)
        } catch {
            AppError.shared.show(
                """
                업데이트에 실패했습니다.
                \(error.localizedDescription)
                """,
                type: .server)
        }
    }
    
    func loadChatRoomBackGroundColor() {
        
    }

}


