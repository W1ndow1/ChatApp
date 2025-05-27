//
//  GalleryViewModel.swift
//  ChatApp
//
//  Created by window1 on 5/21/25.
//

import Foundation
import SDWebImage
import Photos
import SwiftUICore

class GalleryViewModel: ObservableObject {
    @Published var images = [GalleryImageItem]()
    @Published var sharedImage = UIImage()
    @Published var tapTimer: DispatchWorkItem?
    @Published var showTopBottomView: Bool = true
    @Published var scale: CGFloat = 1.0
    @Published var currentIndex: Int = 0 {
        didSet {
            fetchCurrentImage()
        }
    }
    
    func setImages(_ newImages: [GalleryImageItem], _ startIndex: Int) {
        self.images = newImages
        self.currentIndex = startIndex
    }
    
    func saveImageFromCache(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        SDWebImageManager.shared.loadImage(
            with: url,
            options: .highPriority,
            progress: nil) { image, data, error, cacheType, finished, url in
                if let image = image {
                    PHPhotoLibrary.requestAuthorization { status in
                        if status == .authorized {
                            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                            print("이미지 저장 성공")
                        } else {
                            print("접근 권한이 필요합니다.")
                        }
                    }
                } else {
                    print("이미지 로드 실패 \(error?.localizedDescription ?? "")")
                }
        }
    }
    
    func fetchCurrentImage() {
        guard images.indices.contains(currentIndex) else { return }
        let url = images[currentIndex].url
        getImageFromCache(urlString: url) { image in
            DispatchQueue.main.async {
                if let image = image {
                    self.sharedImage = image
                }
            }
        }
    }
    
    
    func getImageFromCache(urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        SDWebImageManager.shared.loadImage(
            with: url,
            options: .highPriority,
            progress: nil) { image, _, error , _, _, _  in
                if let image = image {
                    completion(image)
                } else {
                    completion(nil)
                }
        }
    }
    
   
}
