//
//  Popup.swift
//  ChatApp
//
//  Created by window1 on 4/2/25.
//

import SwiftUI

struct PopupView: View {
    @State private var showPopup = false
    
    var body: some View {
        NavigationStack {
            VStack {
                Button {
                    showPopup = true
                } label: {
                    Text("확인")
                        .padding(20)
                        .foregroundStyle(.white)
                        .background(Color.teal)
                        .clipShape(Capsule())
                }
                
            }
            .bottomPopup(isPresented: $showPopup) {
                VStack {
                    HStack {
                        Text("팝업")
                            .font(.title2)
                            .bold()
                        Spacer()
                        Button("X") {
                            showPopup = false
                        }
                        .background(Color.customAlert)
                        .foregroundStyle(Color.white)
                    }
                    .padding(10)
                    Spacer()
                }
            }
        }
        .animation(.easeIn(duration: 0.3), value: showPopup)
    }
}

#Preview {
    PopupView()
}

enum PopupPositon: CGFloat, CaseIterable {
    case normal = 300
    case expend = 600
}


struct BottomPopupModifier<PopupContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let popupContent: () -> PopupContent
    
    //팝업 위치 상태
    @GestureState private var dragOffset = CGSize.zero
    @State private var currentPosition: PopupPositon = .normal
    
    func body(content: Content) -> some View {
        ZStack(alignment:.bottom) {
            content
            if isPresented {
                Color.gray.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isPresented = false
                    }
                Spacer()
                VStack(spacing: 0) {
                    Capsule()
                        .fill(Color.gray)
                        .frame(width: 60, height: 5)
                        .gesture(drag)
                        .padding(5)
                    popupContent()
                        .padding(.top, 10)
                }
                .frame(height: currentPosition.rawValue)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(radius: 2)
                .offset(y: dragOffset.height > 0 ? dragOffset.height : 0)
                .transition(.move(edge: .bottom))
                .animation(.easeInOut, value: isPresented)
            }
        }
        .ignoresSafeArea()
        .onChange(of: isPresented) {  _, newValue in
            if newValue {
                currentPosition = .normal
            }
        }
    }
    var drag: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                let dragY = value.translation.height
                withAnimation {
                    
                    switch currentPosition {
                    case .normal:
                        if dragY > 100 {
                            isPresented = false
                        } else if dragY < -50 {
                            currentPosition = .expend
                        }
                    case .expend:
                        if dragY > 50 {
                            currentPosition = .normal
                        }
                    }
                }
            }
    }
}

extension View {
    func bottomPopup<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        self.modifier(BottomPopupModifier(isPresented: isPresented, popupContent: content))
    }
}
