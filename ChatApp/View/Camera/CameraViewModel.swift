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
    @Published var thumnailImage: Image?
    
    init() {
        Task {
            await handleCameraPreviews()
        }
    }
    
    func handleCameraPreviews() async {
        let imageStream = camera.previewStream.map { $0.image }
        
        for await image in imageStream {
            Task { @MainActor in
                viewFinderImage = image
            }
        }
    }
    
    func handleCameraPhotos() async {
        
    }
}

fileprivate extension CIImage {
    var image: Image? {
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(self, from: self.extent) else { return nil }
        return Image(decorative: cgImage, scale: 1, orientation: .up)
    }
}
