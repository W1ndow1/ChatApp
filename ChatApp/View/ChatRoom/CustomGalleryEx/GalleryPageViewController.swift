//
//  CustomPageViewController.swift
//  ChatApp
//
//  Created by window1 on 7/22/25.
//

import SwiftUI
import UIKit
import Combine

//SwiftUI에서 사용을 하기 위해 Representable사용
struct PageViewController: UIViewControllerRepresentable {
    var galleryItems: [GalleryImageItem]
    var initialPageIndex: Int
    @Binding var currentPage: Int
    @Binding var showTopBottomView: Bool
    
    func makeUIViewController(context: Context) -> some UIPageViewController {
        let pageViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: nil
        )
        pageViewController.dataSource = context.coordinator
        pageViewController.delegate = context.coordinator

        //초기 뷰 컨트롤러 설정
        if let initialVC = context.coordinator.detailViewController(index: initialPageIndex) {
            pageViewController.setViewControllers([initialVC], direction: .forward, animated: false, completion: nil)
        }
        
        return pageViewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        //이미지 URL 배열이 변경되었거나, currentPage가 변경될때 UI 업데이트
        if uiViewController.viewControllers?.first?.view.tag != currentPage {
            let direction: UIPageViewController.NavigationDirection = currentPage > context.coordinator.previousPage ? .forward : .reverse
            if let targetVC = context.coordinator.detailViewController(index: currentPage) {
                uiViewController.setViewControllers([targetVC], direction: direction, animated: true)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        //초기화시 galleryItems와 초기 페이지 인덱스 전달
        Coordinator(self, galleryItems: galleryItems, initialPageIndex: initialPageIndex, showTopBottomView: $showTopBottomView)
    }
    
    // MARK: - Coordinator Class for UIPageViewController
    
    class Coordinator: NSObject, UIPageViewControllerDelegate, UIPageViewControllerDataSource {
        var parent: PageViewController
        var viewControllers: [UIHostingController<ImageViewController>] = []
        var previousPage: Int //페이지 전환 방향 결정을 위한 페이지 인덱스
        @Binding var showTopBottomView: Bool
        
        
        //각 이미지 URL에 대한 UIHostingController 생성
        init(_ pageViewController: PageViewController, galleryItems: [GalleryImageItem], initialPageIndex: Int, showTopBottomView: Binding<Bool>) {
            self.parent = pageViewController
            self.previousPage = initialPageIndex
            _showTopBottomView = showTopBottomView
            
            //각 페이지 마다 줌 이 가능하도록 설정
            self.viewControllers = galleryItems.enumerated().map { index, item in
                let url = URL(string: item.url)
                let hostingController = UIHostingController(
                    rootView: ImageViewController(
                        imageUrl: url,
                        currentZoomScale: .constant(1.0),
                        showTopBottomView: showTopBottomView
                    )
                )
                hostingController.view.backgroundColor = .black
                hostingController.view.tag = index
                return hostingController
            }
        }
        
        func detailViewController(index: Int) -> UIViewController? {
            guard index >= 0 && index < viewControllers.count else { return nil }
            return viewControllers[index]
        }
        
        //MARK: UIPageViewControllerDataSource Methods
        //좌우 사진 이동시 현재 뷰 컨트롤러의 인덱스 찾기
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            let index = viewController.view.tag
            let previousIndex = index - 1
            guard previousIndex >= 0 else { return nil }
            return detailViewController(index: previousIndex)
        }
        
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            let index = viewController.view.tag
            let nextIndex = index + 1
            guard nextIndex < parent.galleryItems.count else { return nil }
            return detailViewController(index: nextIndex)
        }
        
        //MARK: UIPageViewControllerDelegate Methods
        //페이지 변경이 되면, 현재 보이는 뷰 컨트롤러의 인덱스를 부모 뷰의 currentPage로 바인딩한다.
        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            if completed {
                guard let currentViewController = pageViewController.viewControllers?.first else { return }
                let currentIndex = currentViewController.view.tag
                parent.currentPage = currentIndex
                self.previousPage = currentIndex
            }
        }
    }
}
