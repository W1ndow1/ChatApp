//
//  ImageEdit.swift
//  ChatApp
//
//  Created by window1 on 4/30/25.
//

import Foundation
import UIKit


extension UIImage {
    func resize(to targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    func resizeMaintainningRatio(toWidth width: CGFloat) -> UIImage {
        let scale = width / self.size.width
        let height = self.size.height * scale
        let size = CGSize(width: width, height: height)
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
}
