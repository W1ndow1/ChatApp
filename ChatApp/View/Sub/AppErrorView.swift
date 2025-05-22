//
//  AppErrorView.swift
//  ChatApp
//
//  Created by window1 on 5/22/25.
//

import SwiftUI

struct AppErrorView: View {
    @ObservedObject var appError = AppError.shared
    var body: some View {
        if let error = appError.current {
            VStack {
                Spacer()
                Text(error.message)
                    .padding(10)
                    .foregroundStyle(Color.white)
                    .background(.tint)
                    .font(.system(size: 15, weight: .light))
                    .multilineTextAlignment(.center)
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                    .padding(.horizontal, 15)
                    .onTapGesture {
                        appError.clear()
                    }
                    .transition(.move(edge: .bottom))
                    .zIndex(100)
                Color.clear
                    .frame(height: 30)
                
            }
        }
    }
    
    private func color(for type: ErrorType) -> Color {
        switch type {
        case .network: return Color.orange
        case .server: return Color.red
        case .validation: return Color.blue
        case .unkown: return Color.gray
        }
    }
}


#Preview {
    AppErrorView()
}
