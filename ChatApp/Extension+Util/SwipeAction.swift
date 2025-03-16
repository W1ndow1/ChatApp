//
//  SwipeAction.swift
//  ChatApp
//
//  Created by window1 on 3/15/25.
//

import Foundation
import SwiftUI

struct SwipeActionsView : View {
    @State private var colors: [Color] = [.black, .yellow, .pink, .purple, .brown]
    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(spacing: 2) {
                    ForEach(colors, id:\.self) { color in
                        SwipeAction(content: {
                            CardView(color)
                        }, actions: {
                            Action(tint: .yellow,
                                   icon: "flag",
                                   iconFont: .system(size: 20),
                                   //title: "보관",
                                   //titleFont: .system(size: 15, weight: .bold),
                                   action: {
                                print("save")
                            })
                        })
                    }
                }
                .padding(5)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Messages")
        }
    }
    
    @ViewBuilder
    func CardView(_ color: Color) -> some View {
        HStack(spacing: 12) {
            Circle()
                .frame(width: 50, height: 50)
            VStack(alignment: .leading, spacing: 6, content: {
                RoundedRectangle(cornerRadius: 5)
                .frame(width: 80, height: 5)
                RoundedRectangle(cornerRadius: 5)
                    .frame(width: 60, height: 5)
            })
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white.opacity(0.4))
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(color.gradient)
    }
    
}

struct SwipeAction<Content: View>: View {
    var cornerRadius: CGFloat = 0
    var direction: SwipeDirection = .trailing
    @ViewBuilder var content: Content
    @ActionBuilder var actions: [Action]
    @Environment(\.colorScheme) private var scheme
    let viewId = "ContentView"
    @State private var isEnabled: Bool = true
    @State private var scrollOffset: CGFloat = .zero
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    content
                        .containerRelativeFrame(.horizontal)
                        .background(scheme == .dark ? .black : .white)
                        .id(viewId)
                        .contentShape(.rect)
                        .transition(.identity)
                        .overlay {
                            GeometryReader {
                                let minX = $0.frame(in: .scrollView(axis: .horizontal)).minX
                                Color.clear
                                    .preference(key: OffsetKey.self, value: minX)
                                    .onPreferenceChange(OffsetKey.self) {
                                        scrollOffset = $0
                                    }
                            }
                        }
                    ActionButton {
                        withAnimation(.snappy) {
                            proxy.scrollTo(viewId, anchor: direction == .trailing ? .topLeading : .topTrailing)
                        }
                    }
                    .opacity(scrollOffset == .zero ? 0 : 1)
                }
                .scrollTargetLayout()
                .visualEffect { content, geometryProxy in
                    content
                        .offset(x: scrollOffset(geometryProxy))
                }
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .background {
                if let lastAction = actions.last {
                    Rectangle()
                        .fill(lastAction.tint)
                    
                }
            }
            .clipShape(.rect(cornerRadius: cornerRadius))
        }
        .allowsHitTesting(isEnabled)
        .transition(CustomTransition())
    }
    
    @ViewBuilder
    func ActionButton(resetPosition: @escaping () -> ()) -> some View {
        Rectangle()
            .fill(.clear)
            .frame(width: CGFloat(actions.count) * 80)
            .overlay(alignment: direction.alignment) {
                HStack(spacing: 0) {
                    ForEach(actions) { button in
                        Button(action: {
                            Task {
                                isEnabled = true
                                resetPosition()
                                try? await Task.sleep(for: .seconds(0.25))
                                button.action()
                            }
                        }, label: {
                            VStack(spacing: 5) {
                                Image(systemName: button.icon)
                                    .font(button.iconFont)
                                    .foregroundStyle(button.iconTint)
                                if !button.title.isEmpty {
                                    Text(button.title)
                                        .font(button.titleFont)
                                        .foregroundStyle(button.titleTint)
                                }
                            }
                            .frame(width: 80)
                            .frame(maxHeight: .infinity)  
                        })
                        .buttonStyle(.plain)
                        .background(button.tint)
                    }
                }
            }
    }
    
    func scrollOffset(_ proxy: GeometryProxy) -> CGFloat {
        let minX = proxy.frame(in: .scrollView(axis: .horizontal)).minX
        return direction == .trailing ? (minX > 0 ? -minX : 0) : (minX < 0 ? -minX : 0)
    }
}

///Offset Key
struct OffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

///Custom Transition
struct CustomTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .mask {
                GeometryReader {
                    let size = $0.size
                    Rectangle()
                        .offset(y: phase == .identity ? 0 : -size.height)
                }
                .containerRelativeFrame(.horizontal)
            }
    }
}

///Swipe Direction
enum SwipeDirection {
    case leading
    case trailing
    
    var alignment: Alignment {
        switch self {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        }
        
    }
}

struct Action: Identifiable {
    private(set) var id: UUID = .init()
    var tint: Color
    var icon: String = ""
    var iconFont: Font = .title
    var iconTint: Color = .white
    var title: String = ""
    var titleFont: Font = .system(size: 15)
    var titleTint: Color = .white
    var isEnable: Bool = true
    var action: () -> ()
}

@resultBuilder
struct ActionBuilder {
    static func buildBlock(_ components: Action...) -> [Action] {
        return components
    }
}


#Preview {
    SwipeActionsView()
}
