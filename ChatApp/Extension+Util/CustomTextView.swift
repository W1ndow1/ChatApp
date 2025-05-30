//
//  CustomTextView.swift
//  ChatApp
//
//  Created by window1 on 5/28/25.
//

import SwiftUI
import UIKit

struct CustomTextView: UIViewRepresentable {
    var text: String
    var isMy: Bool
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        
        //텍스트 설정
        textView.text = text
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.textColor = UIColor(isMy ? .white : .black)
        textView.backgroundColor = UIColor(isMy ? .teal : .white)
        
        //스타일
        textView.layer.cornerRadius = 15
        textView.layer.borderWidth = 0.3
        textView.layer.borderColor = UIColor.black.cgColor
        textView.textAlignment = .left
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        textView.translatesAutoresizingMaskIntoConstraints = true
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }
    static func dismantleUIView(_ uiView: UITextView, coordinator: Coordinator) {
        uiView.removeFromSuperview()
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let maxWidth: CGFloat = 200
        let fittingSize = CGSize(width: maxWidth, height: .greatestFiniteMagnitude)
        let size = uiView.sizeThatFits(fittingSize)
        return CGSize(width: min(size.width, maxWidth), height: size.height)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CustomTextView
        
        init(_ parent: CustomTextView) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
        }
    }
}
