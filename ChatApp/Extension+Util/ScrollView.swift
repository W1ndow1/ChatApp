//
//  ScrollView.swift
//  ChatApp
//
//  Created by window1 on 3/7/25.
//

import Foundation
import SwiftUI

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

fileprivate struct Refreshable {
    private let PENDING_THRESHOLD: CGFloat = 40
    private let READY_THRESHOLD: CGFloat = 90
    
    enum State {
        /// The state where the user has not pulled down.
        case none
        /// The state where the user has slightly pulled down but not enough to trigger a refresh.
        case pending
        /// The state where the user has pulled down sufficiently to be ready to trigger a refresh.
        case ready
        /// The state where the user has pulled down completely, and the refresh action is actively running.
        case loading
        
        var indicatorOpacity: CGFloat {
            switch self {
            case .none:
                return 0
            case .pending:
                return 0.2
            case .ready, .loading:
                return 1
            }
        }
    }
    
    private var previousScrollOffset: CGFloat = 0
    
    var scrollViewHeight: CGFloat = 0
    
    var scrollOffset: CGFloat = 0 {
        didSet {
            previousScrollOffset = oldValue
        }
    }
    
    var differentialOffset: CGFloat {
        scrollOffset - previousScrollOffset
    }
    
    var state: State = .none
    
    mutating func updateState(for scrollOffset: CGFloat) {
        self.scrollOffset = scrollOffset

        // If in pending or ready state and canceled before reaching ready
        if state == .pending || (state == .ready && scrollOffset <= 0) {
            state = .none
        }

        // If pulled to pending state where the refresh indicator is visible
        if state == .none && scrollOffset > PENDING_THRESHOLD {
            state = .pending
        }

        // If pulled to ready state confirming the refresh
        if state == .pending && scrollOffset > READY_THRESHOLD {
            state = .ready
        }

        // If in ready state and the view is released (detected by dy), start refresh loading
        if state == .ready
            && scrollOffset > READY_THRESHOLD
            && isDragEnd(dy: differentialOffset) {
            state = .loading
        }
    }

    mutating func reset() {
        state = .none
    }

    
    /// Considered as the user has released their touch and the scroll view is returning to its original state
    /// if the change in the scroll view's offset is significantly negative.
    func isDragEnd(dy: CGFloat) -> Bool {
        return differentialOffset < -10
    }
}

extension View {
    func asIndicator() -> AnyView {
        return AnyView(self)
    }
}

struct RefreshableView<Content: View>: View {
    private let GEOMETRY_HEIGHT: CGFloat = 15
    private let START_PENDING_OFFSET: CGFloat = 40
    private let START_READY_OFFSET: CGFloat = 90
    
    @Namespace private var namespace
    
    @State private var refreshable: Refreshable = .init()
    @State private var isRefreshing: Bool = false
    
    private let reverse: Bool
    @ViewBuilder private var content: () -> Content
    @ViewBuilder private var indicator: () -> AnyView?
    private var onRefresh: () async -> Void
    
    init(
        reverse: Bool = false,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder indicator: @escaping () -> AnyView? = { nil },
        onRefresh: @escaping () async -> Void
    ) {
        self.reverse = reverse
        self.content = content
        self.indicator = indicator
        self.onRefresh = onRefresh
    }
    
    var body: some View {
        ScrollView(.vertical) {
            content()
                .rotationEffect(.degrees(reverse ? 180 : 0))
                .scaleEffect(x: -1)
                .background(
                    GeometryReader { geometry in
                        DispatchQueue.main.async {
                            // Set scroll offset to 0.0 when scrolling up to maximum
                            let scrollOffset = reverse
                            ? -geometry.frame(in: .named(namespace)).maxY + refreshable.scrollViewHeight
                            : geometry.frame(in: .named(namespace)).minY
                            
                            refreshable.updateState(for: scrollOffset)
                            
                            // If in loading state, start the refresh action
                            if refreshable.state == .loading && !isRefreshing {
                                isRefreshing = true
                                Task {
                                    await onRefresh()
                                    DispatchQueue.main.async {
                                        refreshable.reset()
                                        isRefreshing = false
                                    }
                                }
                            }
                        }
                        
                        return Color.clear
                    }
                )
        }
        .coordinateSpace(name: namespace)
        .background(
            GeometryReader { geometry in
                DispatchQueue.main.async {
                    if reverse {
                        refreshable.scrollViewHeight = geometry.size.height
                    }
                }
                return Color.clear
            }
        )
        .overlay {
            VStack {
                Group {
                    if let customIndicator = indicator() {
                        customIndicator
                    } else {
                        basicIndicator
                    }
                }
                .opacity(refreshable.state.indicatorOpacity)
                .offset(y: refreshable.scrollOffset * 0.3)
                .animation(.linear, value: refreshable.state)
                .padding(.top, 10)
                Spacer()
            }
            .rotationEffect(.degrees(reverse ? 180 : 0))
            .scaleEffect(x: -1)
        }
        .rotationEffect(.degrees(reverse ? 180 : 0))
        .scaleEffect(x: -1)
    }
    
    private var basicIndicator: some View {
        Image(systemName: "arrow.up")
            .padding(5)
            .background(Color.gray)
            .cornerRadius(10)
            .foregroundStyle(.black)
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
