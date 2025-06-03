//
//  CameraViewModel.swift
//  ChatApp
//
//  Created by window1 on 4/26/25.
//

import Foundation
import AVFoundation
import SwiftUI

class CameraViewModel: ObservableObject {
    let camera = Camera()
    
    @Published var viewFinderImage: Image?
    @Published var capturedImage: UIImage?
    
    init() {
        Task {
            await handleCameraPreviews()
        }
        Task {
            await handleCameraPhotos()
        }
    }
    
    func handleCameraPreviews() async {
        let imageStream = camera.previewStream.map { $0.image }
        for await image in imageStream {
            await MainActor.run {
                viewFinderImage = image
            }
        }
    }
    
    func handleCameraPhotos() async {
        for await photo in camera.photoStream {
            if let data = photo.fileDataRepresentation(),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    self.capturedImage = uiImage
                }
            }
        }
    }
}

fileprivate extension CIImage {
    var image: Image? {
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(self, from: self.extent) else { return nil }
        return Image(decorative: cgImage, scale: 1, orientation: .up)
    }
}
