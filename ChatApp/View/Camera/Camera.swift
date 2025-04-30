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
    private var photoStreamContinuation: AsyncStream<AVCapturePhoto>.Continuation?
    lazy var photoStream: AsyncStream<AVCapturePhoto> = {
        AsyncStream { continuation in
            self.photoStreamContinuation = continuation
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
                    captureSession.startRunning()
                }
            }
            return
        }
        sessionQueue.async { [self] in
            configureCaptureSession { success in
                guard success else { return }
                configurePhotoOutput()
                captureSession.startRunning()
            }
        }
        
    }
    
    func stop() {
        guard isCaputreSessionConfigured else { return }
        if captureSession.isRunning {
            sessionQueue.async {
                self.captureSession.stopRunning()
            }
        }
    }
    
    //카메라 세션 설정 구성
    private func configureCaptureSession(completion: (_ success: Bool) -> Void) {
        var success = false
        captureSession.beginConfiguration()
        
        defer {
            captureSession.commitConfiguration()
            completion(success)
        }
        
        guard let captureDevice = captureDevice,
              let deviceInput = try? AVCaptureDeviceInput(device: captureDevice)
        else {
            print("Failed to obtain capture device")
            return
        }

        let photoOutput = AVCapturePhotoOutput()
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoDataOutputQueue"))
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        
        
        guard captureSession.canAddInput(deviceInput),
              captureSession.canAddOutput(photoOutput),
              captureSession.canAddOutput(videoOutput) else {
            return
        }
        
        captureSession.addInput(deviceInput)
        captureSession.addOutput(photoOutput)
        captureSession.addOutput(videoOutput)
        
        self.deviceInput = deviceInput
        self.photoOutput = photoOutput
        self.videoOutput = videoOutput
        
        updateVideoMirroring()
        isCaputreSessionConfigured = true
        success = true
    }
    
    private func configurePhotoOutput() {
        guard let photoOutput = self.photoOutput else { return }
        
        if #available(iOS 17.0, *) {
            if let device = self.captureDevice,
               let largestDemension = selectLargestPhotoDemension(for: device) {
                for dim in device.activeFormat.supportedMaxPhotoDimensions {
                    print("\(dim.width)x\(dim.height)")
                }
                photoOutput.maxPhotoDimensions = largestDemension
            }
        } else {
            photoOutput.isHighResolutionCaptureEnabled = true
        }
        photoOutput.maxPhotoQualityPrioritization = .quality
        
    }
    
    
    private func selectLargestPhotoDemension(for device: AVCaptureDevice) -> CMVideoDimensions? {
        let supportedDemension: [CMVideoDimensions] = device.activeFormat.supportedMaxPhotoDimensions
        return supportedDemension.max(by: {($0.width * $0.height) < ($1.width * $1.height)})
    }
    
    
    //전면 카메라일경우 영상 좌우 변경 하는 미러링 설정
    private func updateVideoMirroring() {
        if let videoOutput = videoOutput,
           let videoOutputConnection = videoOutput.connection(with: .video) {
            if videoOutputConnection.isVideoMirroringSupported {
                videoOutputConnection.isVideoMirrored = isUsingFrontCaptureDevice
            }
        }
    }
    
    //캡쳐 디바이스 변경 시 세션 업데이트
    private func updateSessionForCaptureDevice(_ captureDevice: AVCaptureDevice?) {
        guard isCaputreSessionConfigured else { return }
        captureSession.beginConfiguration()
        defer {
            captureSession.commitConfiguration()
        }
        for input in captureSession.inputs {
            if let deviceInput = input as? AVCaptureDeviceInput {
                captureSession.removeInput(deviceInput)
            }
        }
        if let deviceInput = deviceInputFor(device: captureDevice) {
            if !captureSession.inputs.contains(deviceInput), captureSession.canAddInput(deviceInput) {
                captureSession.addInput(deviceInput)
            }
                
        }
        updateVideoMirroring()
    }
    
    //현재 디바이스로 입력 구성하기
    private func deviceInputFor(device: AVCaptureDevice?) -> AVCaptureDeviceInput? {
        guard let vaildDevice = device else { return nil }
        do {
            return try AVCaptureDeviceInput(device: vaildDevice)
        } catch {
            print("Error gettting caputre device input: \(error.localizedDescription)")
            return nil
        }
    }
    
    //접근권한 확인
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
    
    //사진촬영
    func takePhoto() {
        guard let photoOutput = photoOutput else { return }
        
        sessionQueue.async {
            var photoSettings = AVCapturePhotoSettings()
            
            if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            }
            let isFlashAvaliable = self.deviceInput?.device.isFlashAvailable ?? false
            photoSettings.flashMode = isFlashAvaliable ? .auto : .off
            photoSettings.photoQualityPrioritization = .balanced
            
            if let photoOutputVideConnection = photoOutput.connection(with: .video) {
                let angle = self.videoRotationAngle(for: self.deviceOrientation)
                if photoOutputVideConnection.isVideoRotationAngleSupported(angle){
                    photoOutputVideConnection.videoRotationAngle = angle
                }
            }
            photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    //카메라 변경
    func switchCaptureDevice() {
        if let captureDevice = captureDevice,
           let index = availableCaptureDevices.firstIndex(of: captureDevice) {
            let nextIndex = (index + 1) % availableCaptureDevices.count
            self.captureDevice = availableCaptureDevices[nextIndex]
        } else {
            self.captureDevice = AVCaptureDevice.default(for: .video)
        }
    }
    
    @objc
    func updateForDeviceOrientation() {
        
    }
    
    //UIDeviceOrientation -> angle값 가져오기
    private func videoRotationAngle(for deviceOrientation: UIDeviceOrientation) -> Float64 {
        switch deviceOrientation {
        case .portrait:
            return 90
        case .landscapeRight:
            return 180
        case .portraitUpsideDown:
            return 360
        case .landscapeLeft:
            return 0
        default:
            return 90
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

//사진 촬영 완료 후 사진 받기
extension Camera: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            return
        }
        photoStreamContinuation?.yield(photo)
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
