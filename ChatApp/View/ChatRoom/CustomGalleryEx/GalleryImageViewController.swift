import SwiftUI
import SDWebImage
import SDWebImageSwiftUI

struct ImageViewController: UIViewRepresentable {

    let imageUrl: URL?
    @Binding var currentZoomScale: CGFloat
    @Binding var showTopBottomView: Bool
    
    //Called when the view is first created
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .whiteBlack
        
        let imageView = SDAnimatedImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.tag = 100
        
        scrollView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        //이미지 뷰의 크기를 스크롤 뷰의 콘텐츠 크기에 맞추기
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            
            // 이미지 뷰가 스크롤 뷰의 프레임 크기와 동일하도록 설정 (초기 크기)
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
        
        //Add single tap gesture
        let singleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleOrDoubleTap(gesture:)))
        singleTap.numberOfTapsRequired = 1
        imageView.addGestureRecognizer(singleTap)
        
        //Add double tap gesture
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleOrDoubleTap(gesture:)))
        doubleTap.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(doubleTap)
        
        singleTap.require(toFail: doubleTap)
        
        return scrollView
    }
    
    //View will be updated
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        if let imageView = uiView.subviews.first(where: { $0.tag == 100 }) as? SDAnimatedImageView {
            if let url = imageUrl {
                imageView.sd_setImage(with: url, placeholderImage: UIImage(systemName: "photo")) { image, error, cacheType, url in
                    uiView.setZoomScale(uiView.minimumZoomScale, animated: false)
                    context.coordinator.currentZoomScale = uiView.minimumZoomScale // 이미지 로드 후 줌 스케일 초기화 및 바인딩 업데이트
                }
            } else {
                imageView.image = nil
            }
        }
    }
    
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, zoomScale: $currentZoomScale, showTopBottomView: $showTopBottomView)
    }
    
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ImageViewController
        @Binding var currentZoomScale: CGFloat
        @Binding var showTopBottomView: Bool
        
        init(parent: ImageViewController, zoomScale: Binding<CGFloat>, showTopBottomView: Binding<Bool>) {
            self.parent = parent
            _currentZoomScale = zoomScale
            _showTopBottomView = showTopBottomView
        }
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return scrollView.viewWithTag(100)
        }
        
        @objc func handleSingleOrDoubleTap(gesture: UITapGestureRecognizer) {
            guard let imageView = gesture.view as? SDAnimatedImageView,
                  let scrollView = imageView.superview as? UIScrollView else { return }
            if gesture.numberOfTapsRequired == 2 {
                if scrollView.zoomScale > scrollView.minimumZoomScale {
                    scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
                } else {
                    let locationInImageView = gesture.location(in: imageView)
                    let zoomRect = zoomRectForScale(scale: scrollView.maximumZoomScale, center: locationInImageView, scrollView: scrollView)
                    scrollView.zoom(to: zoomRect, animated: true)
                }
            } else if gesture.numberOfTapsRequired == 1 {
                if scrollView.zoomScale == scrollView.minimumZoomScale {
                    showTopBottomView.toggle()
                    imageView.backgroundColor = showTopBottomView ? .whiteBlack : .black
                }
            }
            
        }
        
        @objc func handleDoubleTap(gesture: UITapGestureRecognizer) {
            guard let imageView = gesture.view as? SDAnimatedImageView,
                  let scrollView = imageView.superview as? UIScrollView else { return }
            
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                guard let imageView = scrollView.viewWithTag(100) else { return }
                let locationInImageView = gesture.location(in: imageView)
                
                let zoomRect = zoomRectForScale(scale: scrollView.maximumZoomScale, center: locationInImageView, scrollView: scrollView)
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }
        
        private func zoomRectForScale(scale: CGFloat, center: CGPoint, scrollView: UIScrollView) -> CGRect {
            var zoomRect: CGRect = .zero
            let bounds = scrollView.bounds
            
            zoomRect.size.width = bounds.width / scale
            zoomRect.size.height = bounds.height / scale
            zoomRect.origin.x = center.x - (zoomRect.width / 2.0)
            zoomRect.origin.y = center.y - (zoomRect.height / 2.0)
            
            return zoomRect
        }
    }
}
