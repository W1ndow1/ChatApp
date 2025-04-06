import SwiftUI

struct AlertAction {
    let title: String
    let role: ButtonRole?
    let action: () -> ()
}

struct CustomAlertModifier: ViewModifier {
    
    private let title: String?
    private let message: String?
    private let actions: [AlertAction]
    @Binding var isPresented: Bool
    
    init(title: String?, message: String?, isPresented: Binding<Bool>, actions: [AlertAction] = []) {
        self.title = title
        self.message = message
        self._isPresented = isPresented
        self.actions = actions
    }
    
    func body(content: Content) -> some View {
        ZStack {
            content
            if isPresented {
                Color.gray.opacity(0.3)
                    .ignoresSafeArea()
                VStack {
                    Spacer()
                    VStack(spacing: 15) {
                        if let title = title {
                            Text(title)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        
                        if let message = message {
                            Text(message)
                                .font(.system(size: 15, weight: .light))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                        }
                        if actions.count < 3 {
                            HStack(spacing: 30) {
                                ForEach(actions.indices, id: \.self) { index in
                                    Button {
                                        withAnimation{
                                            isPresented = false
                                        }
                                        actions[index].action()
                                    } label: {
                                        Text(actions[index].title)
                                            .padding(.vertical, 13)
                                            .padding(.horizontal, 20)
                                            .background(actions[index].role == .destructive
                                                        ? Color.pink
                                                        : Color("CustomAlertColor"))
                                            .foregroundStyle(.white)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        } else {
                            VStack(spacing: 10) {
                                ForEach(actions.indices, id: \.self) { index in
                                    Button {
                                        withAnimation{
                                            isPresented = false
                                        }
                                        actions[index].action()
                                    } label: {
                                        Text(actions[index].title)
                                            .padding(.vertical, 13)
                                            .padding(.horizontal, 130)
                                            .background(actions[index].role == .destructive
                                                        ? Color.pink
                                                        : Color("CustomAlertColor"))
                                            .foregroundStyle(.white)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: 295)
                    .padding(20)
                    .background(Color(white: 0.30))
                    .clipShape(RoundedRectangle(cornerRadius: 35))
                }
                .transition(.move(edge: .bottom))
            }
        }
        .animation(.easeOut(duration: 0.3), value: isPresented)
    }
}


extension View {
    func customAlert(title: String?, message: String?, isPresented: Binding<Bool>, actions: [AlertAction]) -> some View {
        self.modifier(CustomAlertModifier(title: title, message: message, isPresented: isPresented, actions: actions))
    }
}
