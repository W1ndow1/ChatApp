//
//  Camera.swift
//  ChatApp
//
//  Created by window1 on 4/26/25.
//
import AVFoundation
import CoreImage
import CoreLocation
import SwiftUI

class Camera: NSObject {
    private let captureSession = AVCaptureSession()     //카메라 세션
    private var isCaputreSessionConfigured = false      //세션 구성 여부
    private var deviceInput: AVCaptureDeviceInput?      //현재 입력 디바이스
    private var photoOutput: AVCapturePhotoOutput?      //사진 캡쳐 아웃풋
    private var videoOutput: AVCaptureVideoDataOutput?  //미리보기용 비디오 아웃풋
    private var sessionQueue: DispatchQueue!            //세션관련 비동기 처리 큐
    private var photoSettings: AVCapturePhotoSettings?
    
    //사용가능 디바이스
    private var allCaptureDevices: [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(deviceTypes: [
            .builtInTrueDepthCamera,
            .builtInDualCamera,
            .builtInDualWideCamera,
            .builtInWideAngleCamera,
            .builtInDualWideCamera
        ], mediaType: .video, position: .unspecified).devices
    }
    
    private var frontCaptureDevices: [AVCaptureDevice] {
        allCaptureDevices.filter { $0.position == .front }
    }
    
    private var backCaptureDevices: [AVCaptureDevice] {
        allCaptureDevices.filter { $0.position == .back }
    }
    
    private var captureDevices: [AVCaptureDevice] {
        var devices = [AVCaptureDevice]()
        #if os(macOS) || (os(iOS) && targetEnvironment(macCatalyst))
        devices += allCaptureDevices
        #else
        if let backDevice = backCaptureDevices.first {
            devices += [backDevice]
        }
        if let frontDevice = frontCaptureDevices.first {
            devices += [frontDevice]
        }
        #endif
        return devices
    }
    
    //연결 상태 및 사용 가능 여부 필터링
    private var availableCaptureDevices: [AVCaptureDevice] {
        captureDevices
            .filter { $0.isConnected }
            .filter { !$0.isSuspended }
    }
    //현재 선택된 카메라 디바이스가 바뀌면 세션 업데이트
    private var captureDevice: AVCaptureDevice? {
        didSet {
            guard let captureDevice = captureDevice else { return }
            sessionQueue.async {
                self.updateSessionForCaptureDevice(captureDevice)
            }
        }
        
    }
    
    //상태확인
    var isRunning: Bool {
        captureSession.isRunning
    }
    var isUsingFrontCaptureDevice: Bool {
        guard let captureDevice = captureDevice else { return false }
        return frontCaptureDevices.contains(captureDevice)
    }
    var isUsingBackCaptureDevice: Bool {
        guard let captureDevice = captureDevice else { return false }
        return backCaptureDevices.contains(captureDevice)
    }
    
    //스트림(사진/미리보기)연결
    private var addToPhotoStream: ((AVCapturePhoto) -> Void)?
    private var addToPreviewStream: ((CIImage) -> Void)?
    var isPreviewPaused = false
    
    //비동기 미리보기
    lazy var previewStream: AsyncStream<CIImage> = {
        AsyncStream { continuation in
            addToPreviewStream = { ciImage in
                if !self.isPreviewPaused {
                    continuation.yield(ciImage)
                }
            }
        }
    }()
    //비동기 사진
    lazy var photoStream: AsyncStream<AVCapturePhoto> = {
        AsyncStream { continuation in
            self.addToPhotoStream = { photo in
                continuation.yield(photo)
            }
        }
    }()
    
    //MARK: - 초기화 및 메서드
    override init() {
        super.init()
        initialize()
    }
    
    private func initialize() {
        sessionQueue = DispatchQueue(label: "session queue")
        captureDevice = availableCaptureDevices.first ?? AVCaptureDevice.default(for: .video)
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(updateForDeviceOrientation),
                                               name: UIDevice.orientationDidChangeNotification,object: nil)
     
    }
    
    func start() async {
        let authorized = await checkAuthorizationStatus()
        guard authorized else {
            print("Camera access was not authroized")
            return
        }
        if isCaputreSessionConfigured {
            if !captureSession.isRunning {
                sessionQueue.async { [self] in
                    self.captureSession.startRunning()
                }
            }
            return
        }
        sessionQueue.async { [self] in
            self.configureCaptureSession { success in
                guard success else { return }
                self.captureSession.startRunning()
            }
        }
        
    }
    //카메라 세션 설정 구성
    private func configureCaptureSession(completion: (_ success: Bool) -> Void) {
        var success = false
        self.captureSession.beginConfiguration()
        defer {
            self.captureSession.commitConfiguration()
            completion(success)
        }
        
        guard let captureDevice = captureDevice,
              let deviceInput = try? AVCaptureDeviceInput(device: captureDevice)
        else {
            print("Failed to obtain capture device")
            return
        }
        let photoOutput = AVCapturePhotoOutput()
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoDataOutputQueue"))
        
        guard captureSession.canAddInput(deviceInput) else {
            return
        }
        guard captureSession.canAddOutput(photoOutput) else {
            return
        }
        guard captureSession.canAddOutput(videoOutput) else {
            return
        }
        
        captureSession.addInput(deviceInput)
        captureSession.addOutput(photoOutput)
        captureSession.addOutput(videoOutput)
        
        self.deviceInput = deviceInput
        self.photoOutput = photoOutput
        self.videoOutput = videoOutput
        
        photoOutput.maxPhotoDimensions = CMVideoDimensions(width: 4000, height: 3000)
        photoOutput.maxPhotoQualityPrioritization = .quality
        
        updateVideoOutputConnection()
        isCaputreSessionConfigured = true
        success = true
        
        
    }
    //전면 카메라일경우 영상 미러링 설정
    private func updateVideoOutputConnection() {
        
    }
    
    private func checkAuthorizationStatus() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("Camera access authorized")
            return true
        case .notDetermined:
            print("Camera access denied")
            sessionQueue.suspend()
            let status = await AVCaptureDevice.requestAccess(for: .video)
            sessionQueue.resume()
            return status
        case .denied:
            print("Camera access denined")
            return false
        case .restricted:
            print("Camera library access restricted")
            return false
        @unknown default:
            return false
        }
    }
    
    func takePhoto() {
        
    }
    
    func switchCaptureDevice() {
        
    }
    
    func updateSessionForCaptureDevice(_ captureDevice: AVCaptureDevice) {
        
    }
    
    @objc
    func updateForDeviceOrientation() {
        
    }
    
    //UIDeviceOrientation -> angle값 가져오기
    private func videoRotationAngle(for deviceOrientation: UIDeviceOrientation) -> Float64 {
        switch deviceOrientation {
        case .portrait:
            return 0
        case .landscapeRight:
            return 90
        case .portraitUpsideDown:
            return 180
        case .landscapeLeft:
            return 270
        default:
            return 0
        }
    }
    
    //현재 디바이스 방향 가져오기
    private var deviceOrientation: UIDeviceOrientation {
        var orientation = UIDevice.current.orientation
        if orientation == UIDeviceOrientation.unknown {
            orientation = UIScreen.main.orientation
        }
        return orientation
    }
 
}

//미리보기 프레임 스트리밍 처리
extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        let angle = self.videoRotationAngle(for: self.deviceOrientation)
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
        addToPreviewStream?(CIImage(cvPixelBuffer: pixelBuffer))
    }
    
    
}

//사진 촬영 완료 후 호출
extension Camera: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            return
        }
        addToPhotoStream?(photo)
    }
}

fileprivate extension UIScreen {

    var orientation: UIDeviceOrientation {
        let point = coordinateSpace.convert(CGPoint.zero, to: fixedCoordinateSpace)
        if point == CGPoint.zero {
            return .portrait
        } else if point.x != 0 && point.y != 0 {
            return .portraitUpsideDown
        } else if point.x == 0 && point.y != 0 {
            return .landscapeRight //.landscapeLeft
        } else if point.x != 0 && point.y == 0 {
            return .landscapeLeft //.landscapeRight
        } else {
            return .unknown
        }
    }
}
