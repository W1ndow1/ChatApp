//
//  ImageCache.swift
//  ChatApp
//
//  Created by window1 on 5/6/25.
//

import Foundation
import UIKit
import CryptoKit

class ImageCacheManager {
    static let shared =  ImageCacheManager()
    
    private let memoryCache = NSCache<NSURL, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxDiskCaheSize: Int64 = 100 * 1024 * 1024
    
    private init () {
        cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }
    
    func image(for url:URL) -> UIImage? {
        //디스크 캐시
        let fileURL = cacheDirectory.appendingPathComponent(cacheFileName(for: url))
        do {
            let data = try Data(contentsOf: fileURL)
            if let image = UIImage(data: data) {
                memoryCache.setObject(image, forKey: url as NSURL)
                return image
            } else {
                print("이미지 객체 생성 실패: Data → UIImage 변환 실패")
            }
        } catch {
            print("파일 읽기 실패: \(error.localizedDescription)")
        }
        return nil
    }
    
    func save(_ image: UIImage, for url: URL) {
        //디스크 캐시
        let fileURL = cacheDirectory.appendingPathComponent(cacheFileName(for: url))
        print("이미지 저장 경로:", fileURL.path)
        if let data = image.jpegData(compressionQuality: 1.0) {
            do {
                try data.write(to: fileURL)
                print("이미지 캐시 저장성공")
            } catch {
                print("이미지 캐시 저장실패:\(error.localizedDescription)")
            }
        }
        diskCacheLimit()
    }
    
    private func cacheFileName(for url: URL) -> String {
        let baseString = url.absoluteString
        let digest = SHA256.hash(data: Data(baseString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    private func diskCacheLimit() {
        DispatchQueue.global(qos: .background).async {
            let files: [URL]
            do {
                files = try self.fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                                                                 options: .skipsHiddenFiles)
            } catch {
                print("Error listing cache files:", error)
                return
            }
            
            var totalSize: Int64 = 0
            var fileInfos: [(url: URL, size: Int64, date: Date)] = []
            
            for fileURL in files {
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: Set([.contentModificationDateKey, .fileSizeKey]))
                    if let fileSize = resourceValues.fileSize,
                       let contentModificationDate = resourceValues.contentModificationDate {
                        totalSize += Int64(fileSize)
                        fileInfos.append((url: fileURL, size: Int64(fileSize), date: contentModificationDate))
                    }
                } catch {
                    continue
                }
            }
            //크키가 작으면 삭제 안함
            if totalSize <= self.maxDiskCaheSize {
                return
            }
            
            //오래된 파일부터 삭제
            fileInfos.sort { $0.date < $1.date}

            for fileInfo in fileInfos {
                do {
                    try self.fileManager.removeItem(at: fileInfo.url)
                    totalSize -= fileInfo.size
                    if totalSize <= self.maxDiskCaheSize {
                        break
                    }
                } catch {
                    print("이미지 캐시파일 삭제 실패:\(fileInfo.url)")
                }
            }
        }
    }
    
    func clearAllCache() {
        //디스크캐시 비우기
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory,
                                                            includingPropertiesForKeys: nil,
                                                            options: .skipsHiddenFiles)
            for fileURL in files {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            print("캐시 삭제 오류:\(error.localizedDescription)")
        }
    }
    
    func totalCacheSize() -> Int64 {
        var size: Int64 = 0
        
        if let enumerator = fileManager.enumerator(at: cacheDirectory,
                                                   includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                                                   options: [.skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                        
                        if resourceValues.isDirectory == false {
                            if let fileSize = resourceValues.fileSize {
                                size += Int64(fileSize)
                            }
                        }
                    } catch {
                        print("Failed to access resource values for \(fileURL.path):", error)
                    }
                }
            }
        return size
    }
}
