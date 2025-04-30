//
//  SwipeAction.swift
//  ChatApp
//
//  Created by window1 on 3/15/25.
//

import Foundation
import SwiftUI

class SwipeState: ObservableObject {
    @Published var activeSwipeId: UUID?
}

struct SwipeActionsView : View {
    @State private var colors: [Color] = [.black, .yellow, .pink, .purple, .brown]
    @StateObject private var swipeState = SwipeState()
    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(spacing: 5) {
                    ForEach(colors, id:\.self) { color in
                        SwipeAction(cornerRadius: 15, direction: .trailing) {
                            CardView(color)
                        } actions: {
                            Action(tint: .yellow,
                                   icon: "book.fill",
                                   iconFont: .system(size: 20, weight: .bold),
                                   title: "즐겨찾기",
                                   titleFont: .system(size: 15, weight: .heavy),
                                   action: {
                                print("save")
                            })
                            Action(tint: .red,
                                   icon: "trash.fill",
                                   isEnabled: color == .black) {
                                withAnimation(.easeInOut) {
                                    colors.removeAll(where: { $0 == color })
                                }
                            }
                        }
                    }
                }
                .padding(5)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Messages")
            .environmentObject(swipeState)
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

    let viewId = "ContentView"
    private let swipeId = UUID()
    @State private var isEnabled: Bool = true
    @State private var scrollOffset: CGFloat = .zero
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var swipeState: SwipeState
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    content
                        .rotationEffect(.init(degrees: direction == .leading ? -180 : 0))
                        .containerRelativeFrame(.horizontal)
                        .background(scheme == .dark ? .black : .white)
                        .background {
                            if let firstAction = filteredActions.first {
                                Rectangle()
                                    .fill(firstAction.tint)
                                    .opacity(scrollOffset == .zero ? 0 : 1)
                            }
                        }
                        .id(viewId)
                        .contentShape(.rect)
                        .transition(.identity)
                        .overlay {
                            GeometryReader {
                                let minX = $0.frame(in: .scrollView(axis: .horizontal)).minX
                                Color.clear
                                    .preference(key: OffsetKey.self, value: minX)
                                    .onPreferenceChange(OffsetKey.self) { value in
                                        let oldOffset = scrollOffset
                                        scrollOffset = value
                                        
                                        // Lower threshold to 20 for better swipe detection
                                        if abs(value) > 20 && abs(oldOffset) <= 20 {
                                            // Add slight delay to ensure smooth animation
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                swipeState.activeSwipeId = swipeId
                                            }
                                        } else if value == 0 && swipeState.activeSwipeId == swipeId {
                                            swipeState.activeSwipeId = nil
                                        }
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
                        .offset(x: geometryProxy.frame(in: .scrollView(axis: .horizontal)).minX > 0 ? -geometryProxy.frame(in: .scrollView(axis: .horizontal)).minX : 0)
                }
            }
            .onChange(of: swipeState.activeSwipeId) { _, newId in
                if newId != swipeId && scrollOffset != 0 {
                    // Add slight delay before resetting position
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.snappy) {
                            proxy.scrollTo(viewId, anchor: direction == .trailing ? .topLeading : .topTrailing)
                        }
                    }
                }
            }
            .scrollDisabled(!isEnabled)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .background {
                if let lastAction = filteredActions.last {
                    Rectangle()
                        .fill(lastAction.tint)
                        .opacity(scrollOffset == .zero ? 0 : 1)
                }
            }
            .clipShape(.rect(cornerRadius: cornerRadius))
            .rotationEffect(.init(degrees: direction == .leading ? 180 : 0))
        }
        .allowsHitTesting(isEnabled)
        .transition(CustomTransition())
    }
    
    @ViewBuilder
    func ActionButton(resetPosition: @escaping () -> ()) -> some View {
        Rectangle()
            .fill(.clear)
            .frame(width: CGFloat(filteredActions.count) * 80)
            .overlay(alignment: direction.alignment) {
                HStack(spacing: 0) {
                    ForEach(filteredActions) { button in
                        Button(action: {
                            Task {
                                swipeState.activeSwipeId = swipeId
                                isEnabled = false
                                resetPosition()
                                try? await Task.sleep(for: .seconds(0.25))
                                button.action()
                                try? await Task.sleep(for: .seconds(0.1))
                                isEnabled = true
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
                        .rotationEffect(.init(degrees: direction == .leading ? -180 : 0))
                    }
                }
            }
    }
    
    @MainActor
    func scrollOffset(_ proxy: GeometryProxy) -> CGFloat {
        let minX = proxy.frame(in: .scrollView(axis: .horizontal)).minX
        return (minX > 0 ? -minX : 0)
    }
    
    var filteredActions: [Action] {
        return actions.filter({ $0.isEnabled })
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
    var isEnabled: Bool = true
    var direction: SwipeDirection = .trailing
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


