//
//  IdentifiableError.swift
//  ChatApp
//
//  Created by window1 on 5/19/25.
//

import Foundation
import SwiftUI

struct IdentifiableError: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let type: ErrorType
}

enum ErrorType: String, CaseIterable {
    case network, server, validation, unkown
}

class AppError: ObservableObject {
    static let shared = AppError()
    
    @Published var current: IdentifiableError? = nil
    
    func show(_ message: String, type: ErrorType = .unkown) {
        withAnimation {
            self.current = IdentifiableError(message: message, type: type)
        }
    }
    
    func clear() {
        withAnimation {
            self.current = nil
        }
    }

}
