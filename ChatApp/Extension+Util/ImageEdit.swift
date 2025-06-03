//
//  ImageEdit.swift
//  ChatApp
//
//  Created by window1 on 4/30/25.
//

import Foundation
import UIKit
import SwiftUI


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

struct ResizedAsyncImage: View {
    let url: URL
    let targetSize: CGSize
    
    @State private var image: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: targetSize.width)
                    .clipped()
            } else {
                ProgressView()
                    .frame(width: targetSize.width, height: targetSize.height)
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        //캐쉬 확인
        if let cachedImage = ImageCache.shared.image(for: url) {
            self.image = cachedImage
            return
        }
        //다운로드
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let originalImage = UIImage(data: data) {
                let resized = resizeMaintainningRatio(originalImage, toWidth: targetSize.width)
                self.image = resized
                ImageCache.shared.save(resized, for: url)
                
            }
        } catch {
            print("Failed to load image:", error)
        }
    }
    
    private func resizeMaintainningRatio(_ image: UIImage, toWidth width: CGFloat) -> UIImage {
        let scale = width / image.size.width
        let height = image.size.height * scale
        let size = CGSize(width: width, height: height)
              
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
