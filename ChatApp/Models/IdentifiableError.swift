//
//  IdentifiableError.swift
//  ChatApp
//
//  Created by window1 on 5/19/25.
//

import Foundation

struct IdentifiableError: Identifiable, Equatable {
    let id = UUID()
    let message: String
}
