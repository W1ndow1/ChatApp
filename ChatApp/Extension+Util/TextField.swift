//
//  TextField.swift
//  ChatApp
//
//  Created by window1 on 3/23/25.
//

import Foundation
import SwiftUI

extension View {
    func characterLimit(limit: Int, text: Binding<String>) -> some View {
        self
            .onChange(of: text.wrappedValue) { oldValue, newValue in
                if newValue.count > limit {
                    text.wrappedValue = String(newValue.prefix(limit))
                }
            }
    }
}
