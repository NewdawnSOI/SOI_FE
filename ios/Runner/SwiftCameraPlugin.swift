import Flutter
import UIKit
import AVFoundation

// 간단한 카메라 플러그인 구현
public class SwiftCameraPlugin: NSObject, FlutterPlugin, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate {
    var captureSession: AVCaptureSession?
    var photoOutput: AVCapturePhotoOutput?
    var currentDevice: AVCaptureDevice?
    var flashMode: AVCaptureDevice.FlashMode = .off
    var isUsingFrontCamera: Bool = false
    var photoCaptureResult: FlutterResult?
    var currentZoomLevel: Double = 1.0  // 현재 줌 레벨 추적
    var movieOutput: AVCaptureMovieFileOutput?
    var audioInput: AVCaptureDeviceInput?
    var videoRecordingResult: FlutterResult?
    var activeVideoURL: URL?
    var videoRecordingTimer: DispatchSourceTimer?
    var isCancellingRecording: Bool = false
    var previousSessionPreset: AVCaptureSession.Preset?
    var methodChannel: FlutterMethodChannel?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        // 플랫폼 채널 등록 및 핸들러 설정
        let channel = FlutterMethodChannel(name: "com.soi.camera", binaryMessenger: registrar.messenger())
        let instance = SwiftCameraPlugin()
        instance.methodChannel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        // 카메라 초기화
        instance.setupCamera()
        
        // 플랫폼 뷰 등록 - nil 체크 추가
        guard let captureSession = instance.captureSession else {
            print("경고: 카메라 세션이 초기화되지 않았습니다")
            return
        }
        
        // 플랫폼 뷰 팩토리 등록
        registrar.register(
            CameraPreviewFactory(captureSession: captureSession),
            withId: "com.soi.camera/preview"
        )
    }
    
    // 기본 카메라 설정
    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo
        
        // 기본 후면 카메라 설정
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            currentDevice = device
            beginSession()
        }
    }
    
    // 카메라 세션 시작
    func beginSession() {
        guard let session = captureSession, let device = currentDevice else { return }
        
        do {
            // 카메라 입력 설정
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            // 사진 출력 설정
            photoOutput = AVCapturePhotoOutput()
            if let photoOutput = photoOutput, session.canAddOutput(photoOutput) {
                // 🎨 색공간 설정: sRGB 강제 (색상 일관성 향상)
                if #available(iOS 11.0, *) {
                    // 가능한 색공간 중 sRGB 선택
                    if photoOutput.availablePhotoPixelFormatTypes.contains(kCVPixelFormatType_32BGRA) {
                        photoOutput.setPreparedPhotoSettingsArray([
                            AVCapturePhotoSettings(format: [
                                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                            ])
                        ], completionHandler: nil)
                        print("🎨 카메라 출력 색공간: sRGB (32BGRA) 설정 완료")
                    }
                }
                
                session.addOutput(photoOutput)
                
                // 사진 출력 연결에는 미러링 적용하지 않음 (원본 이미지 유지)
                if let connection = photoOutput.connection(with: .video) {
                    if connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false
                        connection.isVideoMirrored = false  // 사진은 미러링 없이
                        print("🔧 사진 출력 연결 미러링 비활성화 (원본 이미지 보존)")
                    }
                }
            }
            
            // 세션 시작
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                
                // ✅ 수정: 세션 안정화 후 미러링 적용
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.applyMirroringToAllConnections()
                    print("🔧 카메라 세션 시작 후 미러링 설정 완료")
                }
            }
        } catch {
            print("카메라 세션 설정 오류: \(error)")
        }
    }
    
    // 플랫폼 채널 메서드 처리
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initCamera":
            initCamera(result: result)
        case "takePicture":
            takePicture(result: result)    
        case "switchCamera":
            switchCamera(result: result)
        case "setFlash":
            setFlash(call: call, result: result)
        case "setZoom":
            setZoom(call: call, result: result)
        case "pauseCamera":
            pauseCamera(result: result)
        case "resumeCamera":
            resumeCamera(result: result)
        case "disposeCamera":
            disposeCamera(result: result)
        case "optimizeCamera":
            optimizeCamera(result: result)
        case "getAvailableZoomLevels":
            getAvailableZoomLevels(result: result)
        case "startVideoRecording":
            startVideoRecording(call: call, result: result)
        case "stopVideoRecording":
            stopVideoRecording(result: result)
        case "cancelVideoRecording":
            cancelVideoRecording(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // 카메라 초기화
    func initCamera(result: @escaping FlutterResult) {
        if captureSession == nil {
            setupCamera()
        }
        result("Camera initialized")
    }
    
    // 사진 촬영
    func takePicture(result: @escaping FlutterResult) {
        guard let photoOutput = self.photoOutput else {
            result(FlutterError(code: "NO_PHOTO_OUTPUT", message: "Photo output not available", details: nil))
            return
        }
        
        // 사진 촬영 설정
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        
        // 🎨 색공간을 sRGB로 명시적 설정 (색상 일관성 향상)
        if #available(iOS 13.0, *) {
            let desiredPriority: AVCapturePhotoOutput.QualityPrioritization = .quality
            let maxSupportedPriority = photoOutput.maxPhotoQualityPrioritization

            if desiredPriority.rawValue <= maxSupportedPriority.rawValue {
                settings.photoQualityPrioritization = desiredPriority
            } else {
                settings.photoQualityPrioritization = maxSupportedPriority
            }
        }
        
        // 색공간 설정은 photoOutput에서 처리됨 (아래 setupPhotoOutput 참조)
        
        // 전면 카메라인 경우 특별한 설정 추가
        if currentDevice?.position == .front {
            print("🔧 전면 카메라 설정 적용")
            // 필요시 전면 카메라 전용 설정 추가
        }
        
        print("📸 사진 촬영 시작 - 출력 미러링 비활성화 상태")
        photoCaptureResult = result
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // 사진 촬영 완료 처리
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            photoCaptureResult?(FlutterError(code: "CAPTURE_ERROR", message: error.localizedDescription, details: nil))
            return
        }
        
        // 이미지 데이터 얻기
        guard let imageData = photo.fileDataRepresentation() else {
            photoCaptureResult?(FlutterError(code: "NO_IMAGE_DATA", message: "Could not get image data", details: nil))
            return
        }
        
        // 현재 카메라 위치 직접 확인
        let isFrontCamera = currentDevice?.position == .front
        print("🔍 현재 카메라 위치: \(isFrontCamera ? "전면" : "후면")")
        
        // UIImage로 변환
        guard let originalImage = UIImage(data: imageData) else {
            photoCaptureResult?(FlutterError(code: "IMAGE_CONVERSION_ERROR", message: "Could not convert image data to UIImage", details: nil))
            return
        }
        
        print("📸 원본 이미지 크기: \(originalImage.size)")
        print("📸 원본 이미지 orientation: \(originalImage.imageOrientation.rawValue)")
        
        // 이미지 방향 및 반전 처리
        var finalImage: UIImage = originalImage
        
        // 모든 카메라에서 원본 이미지 그대로 사용 (좌우반전 해제)
        print("📸 \(isFrontCamera ? "전면" : "후면") 카메라: 원본 이미지 사용 (좌우반전 해제)")
        
        // 처리된 이미지를 JPEG 데이터로 변환
        guard let processedImageData = finalImage.jpegData(compressionQuality: 0.9) else {
            photoCaptureResult?(FlutterError(code: "IMAGE_PROCESSING_ERROR", message: "Could not convert processed image to JPEG", details: nil))
            return
        }
        
        // 임시 파일로 저장
        let tempDir = NSTemporaryDirectory()
        let filePath = tempDir + "/\(UUID().uuidString).jpg"
        let fileURL = URL(fileURLWithPath: filePath)
        
        do {
            try processedImageData.write(to: fileURL)
            photoCaptureResult?(filePath)
            print("✅ 이미지 저장 완료: \(filePath)")
        } catch {
            photoCaptureResult?(FlutterError(code: "FILE_SAVE_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    // MARK: - Video Recording
    func startVideoRecording(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let captureSession = captureSession else {
            result(FlutterError(code: "SESSION_ERROR", message: "Camera session is not initialized", details: nil))
            return
        }
        
        if movieOutput?.isRecording == true {
            result(FlutterError(code: "ALREADY_RECORDING", message: "Video recording already in progress", details: nil))
            return
        }
        
        let args = call.arguments as? [String: Any]
        let requestedDurationMs = args?["maxDurationMs"] as? Int ?? 30_000
        let durationSeconds = max(1.0, min(Double(requestedDurationMs) / 1000.0, 30.0))
        
        previousSessionPreset = captureSession.sessionPreset
        if captureSession.sessionPreset != .high {
            captureSession.beginConfiguration()
            if captureSession.canSetSessionPreset(.high) {
                captureSession.sessionPreset = .high
            }
            captureSession.commitConfiguration()
        }
        
        do {
            try attachAudioInputIfNeeded()
        } catch {
            result(FlutterError(code: "AUDIO_ERROR", message: "Failed to attach audio input", details: error.localizedDescription))
            return
        }
        
        guard let movieOutput = prepareMovieOutputIfNeeded() else {
            result(FlutterError(code: "VIDEO_OUTPUT_ERROR", message: "Unable to prepare movie output", details: nil))
            return
        }
        
        configureMovieOutputConnection(movieOutput)
        videoRecordingResult = nil
        
        if captureSession.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }
        }
        
        let tempDir = NSTemporaryDirectory()
        let fileURL = URL(fileURLWithPath: tempDir).appendingPathComponent("\(UUID().uuidString).mov")
        activeVideoURL = fileURL
        isCancellingRecording = false
        
        movieOutput.maxRecordedDuration = CMTimeMakeWithSeconds(durationSeconds, preferredTimescale: 600)
        startVideoTimeoutTimer(duration: durationSeconds + 0.5)
        
        movieOutput.startRecording(to: fileURL, recordingDelegate: self)
        result(true)
    }
    
    func stopVideoRecording(result: @escaping FlutterResult) {
        guard let movieOutput = movieOutput, movieOutput.isRecording else {
            result(FlutterError(code: "NO_ACTIVE_RECORDING", message: "No active video recording to stop", details: nil))
            return
        }
        
        videoRecordingResult = result
        isCancellingRecording = false
        stopVideoTimeoutTimer()
        movieOutput.stopRecording()
    }
    
    func cancelVideoRecording(result: @escaping FlutterResult) {
        guard let movieOutput = movieOutput, movieOutput.isRecording else {
            result(FlutterError(code: "NO_ACTIVE_RECORDING", message: "No active video recording to cancel", details: nil))
            return
        }
        
        videoRecordingResult = result
        isCancellingRecording = true
        stopVideoTimeoutTimer()
        movieOutput.stopRecording()
    }
    
    private func attachAudioInputIfNeeded() throws {
        guard let captureSession = captureSession else { return }
        
        if audioInput != nil {
            return
        }
        
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            throw NSError(domain: "SwiftCameraPlugin", code: -1, userInfo: [NSLocalizedDescriptionKey: "Audio device unavailable"])
        }
        
        let input = try AVCaptureDeviceInput(device: audioDevice)
        
        captureSession.beginConfiguration()
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
            captureSession.commitConfiguration()
            audioInput = input
        } else {
            captureSession.commitConfiguration()
            throw NSError(domain: "SwiftCameraPlugin", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unable to attach audio input"])
        }
    }
    
    private func detachAudioInputIfNeeded() {
        guard let captureSession = captureSession, let audioInput = audioInput else { return }
        
        captureSession.beginConfiguration()
        captureSession.removeInput(audioInput)
        captureSession.commitConfiguration()
        self.audioInput = nil
    }
    
    private func prepareMovieOutputIfNeeded() -> AVCaptureMovieFileOutput? {
        if let movieOutput = movieOutput {
            return movieOutput
        }
        
        guard let captureSession = captureSession else { return nil }
        let output = AVCaptureMovieFileOutput()
        
        captureSession.beginConfiguration()
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
            captureSession.commitConfiguration()
            movieOutput = output
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.applyMirroringToAllConnections()
            }
            return output
        } else {
            captureSession.commitConfiguration()
            return nil
        }
    }
    
    private func configureMovieOutputConnection(_ movieOutput: AVCaptureMovieFileOutput) {
        guard let connection = movieOutput.connection(with: .video) else { return }
        
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        
        if connection.isVideoStabilizationSupported {
            connection.preferredVideoStabilizationMode = .cinematic
        }
        
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
    }
    
    private func restoreSessionPresetIfNeeded() {
        guard let captureSession = captureSession else { return }
        
        if let previousPreset = previousSessionPreset, captureSession.canSetSessionPreset(previousPreset) {
            captureSession.beginConfiguration()
            captureSession.sessionPreset = previousPreset
            captureSession.commitConfiguration()
        } else if captureSession.sessionPreset != .photo && captureSession.canSetSessionPreset(.photo) {
            captureSession.beginConfiguration()
            captureSession.sessionPreset = .photo
            captureSession.commitConfiguration()
        }
        
        previousSessionPreset = nil
    }
    
    private func startVideoTimeoutTimer(duration: TimeInterval) {
        stopVideoTimeoutTimer()
        
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now() + duration)
        timer.setEventHandler { [weak self] in
            guard let self = self, let movieOutput = self.movieOutput else { return }
            if movieOutput.isRecording {
                self.isCancellingRecording = false
                movieOutput.stopRecording()
            }
        }
        videoRecordingTimer = timer
        timer.resume()
    }
    
    private func stopVideoTimeoutTimer() {
        videoRecordingTimer?.setEventHandler {}
        videoRecordingTimer?.cancel()
        videoRecordingTimer = nil
    }
    
    private func cleanupAfterVideoRecording() {
        stopVideoTimeoutTimer()
        restoreSessionPresetIfNeeded()
        detachAudioInputIfNeeded()
        movieOutput?.maxRecordedDuration = CMTime.invalid
        activeVideoURL = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.applyMirroringToAllConnections()
        }
    }
    
    // AVCaptureFileOutputRecordingDelegate
    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        let pendingResult = videoRecordingResult
        videoRecordingResult = nil
        let wasCancelled = isCancellingRecording
        isCancellingRecording = false
        
        cleanupAfterVideoRecording()
        
        if let error = error {
            try? FileManager.default.removeItem(at: outputFileURL)
            pendingResult?(FlutterError(code: "VIDEO_RECORDING_ERROR", message: error.localizedDescription, details: nil))
            DispatchQueue.main.async { [weak self] in
                self?.methodChannel?.invokeMethod("onVideoError", arguments: ["message": error.localizedDescription])
            }
            return
        }
        
        if wasCancelled {
            try? FileManager.default.removeItem(at: outputFileURL)
            pendingResult?("")
            return
        }
        
        pendingResult?(outputFileURL.path)
        DispatchQueue.main.async { [weak self] in
            self?.methodChannel?.invokeMethod("onVideoRecorded", arguments: ["path": outputFileURL.path])
        }
    }
    
    // 이미지 좌우반전 처리 - 최종 개선 버전
    func flipImageHorizontally(_ image: UIImage) -> UIImage {
        // 1. UIImage orientation 방법 시도
        if let cgImage = image.cgImage {
            let flippedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: .upMirrored)
            print("✅ 이미지 좌우반전 완료 (UIImage orientation 방법)")
            return flippedImage
        }
        
        // 2. Core Graphics 방법으로 폴백
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext(),
              let cgImage = image.cgImage else {
            print("⚠️ 좌우반전 실패 - 원본 이미지 반환")
            return image
        }
        
        // 좌우반전 변환 적용
        context.translateBy(x: image.size.width, y: 0)
        context.scaleBy(x: -1.0, y: 1.0)
        
        // 이미지 그리기
        context.draw(cgImage, in: CGRect(origin: .zero, size: image.size))
        
        guard let flippedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            print("⚠️ Core Graphics 좌우반전 실패 - 원본 이미지 반환")
            return image
        }
        
        print("✅ 이미지 좌우반전 완료 (Core Graphics 방법)")
        return flippedImage
    }
    
    // 후면 카메라 방향 수정 (상하 반전 해결)
    func fixBackCameraOrientation(_ image: UIImage) -> UIImage {
        // 원본 이미지의 방향 확인
        let originalOrientation = image.imageOrientation
        print("📸 후면 카메라 원본 방향: \(originalOrientation.rawValue)")
        
        guard let cgImage = image.cgImage else {
            print("⚠️ 후면 카메라 방향 수정 실패 - 원본 이미지 반환")
            return image
        }
        
        // 이미 올바른 방향이면 그대로 반환
        if originalOrientation == .up {
            print("✅ 후면 카메라 이미 올바른 방향")
            return image
        }
        
        // Core Graphics를 사용하여 이미지를 올바른 방향으로 그리기
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: image.size))
        
        guard let correctedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            print("⚠️ 후면 카메라 방향 수정 실패 - 원본 이미지 반환")
            return image
        }
        
        print("✅ 후면 카메라 방향 수정 완료")
        return correctedImage
    }
    
    // 프리뷰 연결에만 미러링 적용 (사진 출력 제외)
    func applyMirroringToAllConnections() {
        guard let captureSession = captureSession else { return }
        
        // 현재 카메라 타입 확인
        let isFrontCamera = currentDevice?.position == .front
        
        // 모든 출력의 연결을 확인하고 적절히 미러링 적용
        for output in captureSession.outputs {
            // 사진 및 동영상 출력은 항상 미러링 비활성화 (원본 미디어 유지)
            if output is AVCapturePhotoOutput || output is AVCaptureMovieFileOutput {
                for connection in output.connections {
                    if connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false
                        connection.isVideoMirrored = false
                        print("🔧 캡처 출력 연결 미러링 비활성화")
                    }
                }
            } else {
                // 프리뷰 출력은 전면 카메라에서만 미러링 활성화
                for connection in output.connections {
                    if connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false
                        connection.isVideoMirrored = isFrontCamera
                        print("🔧 프리뷰 출력 연결 미러링: \(isFrontCamera ? "전면 카메라 - 활성화" : "후면 카메라 - 비활성화")")
                    }
                }
            }
        }
    }
    
    // 카메라 전환
    func switchCamera(result: @escaping FlutterResult) {
        guard let captureSession = captureSession,
              let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput else {
            result(FlutterError(code: "NO_CAMERA", message: "No current camera", details: nil))
            return
        }
        
        captureSession.beginConfiguration()
        captureSession.removeInput(currentInput)
        
        // 전/후면 카메라 전환
        isUsingFrontCamera.toggle()
        let newPosition: AVCaptureDevice.Position = isUsingFrontCamera ? .front : .back
        
        if let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) {
            currentDevice = newDevice
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                if captureSession.canAddInput(newInput) {
                    captureSession.addInput(newInput)
                }
            } catch {
                result(FlutterError(code: "SWITCH_ERROR", message: error.localizedDescription, details: nil))
                captureSession.commitConfiguration()
                return
            }
        }
        
        captureSession.commitConfiguration()
        
        // ✅ 수정: 카메라 전환 후 안정화 시간을 두고 미러링 설정 적용
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.applyMirroringToAllConnections()
            print("🔧 카메라 전환 완료 - \(self.isUsingFrontCamera ? "전면" : "후면") 카메라, 미러링 재설정")
        }
        
        result("Camera switched")
    }
    
    // 플래시 설정
    func setFlash(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let isOn = args["isOn"] as? Bool else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing or invalid isOn parameter", details: nil))
            return
        }
        
        flashMode = isOn ? .on : .off
        result("Flash set to \(isOn ? "on" : "off")")
    }
    
    // 줌 설정 - 물리적 렌즈 전환 지원
    func setZoom(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let zoomValue = args["zoomValue"] as? Double else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing or invalid zoomValue parameter", details: nil))
            return
        }
        
        guard let captureSession = captureSession else {
            result(FlutterError(code: "NO_SESSION", message: "No capture session available", details: nil))
            return
        }
        
        // 전면 카메라는 줌 변경 불가
        if isUsingFrontCamera {
            result("Front camera does not support zoom")
            return
        }
        
        currentZoomLevel = zoomValue
        
        // 물리적 망원 카메라 존재 여부 확인
        let hasTelephoto = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back) != nil
        
        // 줌 레벨에 따른 카메라 선택
        let targetCameraType: AVCaptureDevice.DeviceType
        let digitalZoomFactor: CGFloat
        
        if zoomValue < 0.75 {
            // 0.5x - 초광각 카메라
            targetCameraType = .builtInUltraWideCamera
            digitalZoomFactor = CGFloat(zoomValue * 2.0)  // 0.5x = 1.0 factor on ultra wide
            print("📱 줌 설정: 0.5x 초광각 카메라 사용")
        } else if zoomValue < 1.5 {
            // 1.0x - 일반 광각 카메라
            targetCameraType = .builtInWideAngleCamera
            digitalZoomFactor = CGFloat(zoomValue)
            print("📱 줌 설정: 1.0x 광각 카메라 사용")
        } else if zoomValue < 2.5 && hasTelephoto {
            // 2.0x - 물리적 망원 카메라가 있으면 사용
            targetCameraType = .builtInTelephotoCamera
            digitalZoomFactor = 1.0  // 망원 카메라의 기본 배율
            print("📱 줌 설정: 2.0x 물리적 망원 카메라 사용")
        } else if zoomValue >= 3.0 && hasTelephoto {
            // 3.0x - 물리적 망원 카메라가 있으면 망원 카메라에서 디지털 줌
            targetCameraType = .builtInTelephotoCamera
            digitalZoomFactor = CGFloat(zoomValue / 2.0)  // 망원 카메라 기준으로 디지털 줌
            print("📱 줌 설정: 3.0x 물리적 망원 카메라 + 디지털 줌 사용")
        } else {
            // 망원 카메라가 없거나 다른 경우 - 광각에서 디지털 줌
            targetCameraType = .builtInWideAngleCamera
            digitalZoomFactor = CGFloat(zoomValue)
            print("📱 줌 설정: \(zoomValue)x 광각 카메라 디지털 줌 사용 (망원 카메라 없음)")
        }
        
        // 목표 카메라 가져오기
        guard let newDevice = AVCaptureDevice.default(targetCameraType, for: .video, position: .back) else {
            // 목표 카메라가 없으면 현재 카메라에서 디지털 줌만 적용
            if let currentDevice = currentDevice {
                do {
                    try currentDevice.lockForConfiguration()
                    let maxZoom = currentDevice.activeFormat.videoMaxZoomFactor
                    let finalZoom = min(CGFloat(zoomValue), maxZoom)
                    currentDevice.ramp(toVideoZoomFactor: finalZoom, withRate: 2.0)
                    currentDevice.unlockForConfiguration()
                    result("Digital zoom set to \(zoomValue)x")
                } catch {
                    result(FlutterError(code: "ZOOM_ERROR", message: error.localizedDescription, details: nil))
                }
            }
            return
        }
        
        // 카메라가 변경되어야 하는 경우
        if newDevice != currentDevice {
            captureSession.beginConfiguration()
            
            // 기존 입력 제거
            if let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput {
                captureSession.removeInput(currentInput)
            }
            
            // 새 입력 추가
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                if captureSession.canAddInput(newInput) {
                    captureSession.addInput(newInput)
                    currentDevice = newDevice
                }
                
                // 디지털 줌 적용
                try newDevice.lockForConfiguration()
                let maxZoom = newDevice.activeFormat.videoMaxZoomFactor
                let finalZoom = min(digitalZoomFactor, maxZoom)
                newDevice.videoZoomFactor = finalZoom
                newDevice.unlockForConfiguration()
                
            } catch {
                result(FlutterError(code: "CAMERA_SWITCH_ERROR", message: error.localizedDescription, details: nil))
                captureSession.commitConfiguration()
                return
            }
            
            captureSession.commitConfiguration()
            
            // 미러링 재설정
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.applyMirroringToAllConnections()
            }
            
            result("Zoom set to \(zoomValue)x with camera switch")
        } else {
            // 같은 카메라에서 디지털 줌만 조정
            do {
                try currentDevice?.lockForConfiguration()
                let maxZoom = currentDevice?.activeFormat.videoMaxZoomFactor ?? 1.0
                let finalZoom = min(digitalZoomFactor, maxZoom)
                currentDevice?.videoZoomFactor = finalZoom
                currentDevice?.unlockForConfiguration()
                result("Zoom adjusted to \(zoomValue)x")
            } catch {
                result(FlutterError(code: "ZOOM_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }
    
    // 카메라 세션 일시 중지
    func pauseCamera(result: @escaping FlutterResult) {
        guard let captureSession = captureSession else {
            result(FlutterError(code: "SESSION_ERROR", message: "Camera session is not initialized", details: nil))
            return
        }
        
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
        
        result("Camera paused")
    }
    
    // 카메라 세션 재개
    func resumeCamera(result: @escaping FlutterResult) {
        guard let captureSession = captureSession else {
            result(FlutterError(code: "SESSION_ERROR", message: "Camera session is not initialized", details: nil))
            return
        }
        
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
                
                // ✅ 수정: 세션 재개 후 안정화 시간을 두고 미러링 재설정
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.applyMirroringToAllConnections()
                    print("🔧 카메라 세션 재개 후 미러링 설정 완료")
                }
            }
        }
        
        result("Camera resumed")
    }
    
    // 카메라 리소스 해제
    func disposeCamera(result: @escaping FlutterResult) {
        guard let captureSession = captureSession else {
            result(FlutterError(code: "SESSION_ERROR", message: "Camera session is not initialized", details: nil))
            return
        }
        
        if let movieOutput = movieOutput, movieOutput.isRecording {
            movieOutput.stopRecording()
        }
        cleanupAfterVideoRecording()
        
        if let movieOutput = movieOutput {
            captureSession.beginConfiguration()
            captureSession.removeOutput(movieOutput)
            captureSession.commitConfiguration()
            self.movieOutput = nil
        }
        
        captureSession.stopRunning()
        result("Camera disposed")
    }
    
    // 카메라 최적화 - 간단한 구현
    func optimizeCamera(result: @escaping FlutterResult) {
        guard let currentDevice = currentDevice else {
            result(FlutterError(code: "NO_CAMERA", message: "No camera available", details: nil))
            return
        }
        
        do {
            try currentDevice.lockForConfiguration()
            
            // 자동 초점 설정
            if currentDevice.isFocusModeSupported(.continuousAutoFocus) {
                currentDevice.focusMode = .continuousAutoFocus
            }
            
            // 자동 노출 설정
            if currentDevice.isExposureModeSupported(.continuousAutoExposure) {
                currentDevice.exposureMode = .continuousAutoExposure
            }
            
            currentDevice.unlockForConfiguration()
            result("Camera optimized")
        } catch {
            result(FlutterError(code: "OPTIMIZATION_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    // MARK: - 이미지 처리 헬퍼 메서드
    
    // 사용 가능한 줌 레벨 확인 - 물리적 카메라 구성에 따른 정확한 레벨 반환
    func getAvailableZoomLevels(result: @escaping FlutterResult) {
        var levels: [Double] = []
        var hasUltraWide = false
        var hasTelephoto = false
        
        // 후면 카메라만 줌 지원
        if !isUsingFrontCamera {
            // 초광각 카메라 체크 (0.5x)
            if AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) != nil {
                hasUltraWide = true
                levels.append(0.5)
            }
            
            // 광각 카메라는 항상 있음 (1.0x)
            levels.append(1.0)
            
            // 망원 카메라 체크
            let telephotoDevice = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
            if let telephoto = telephotoDevice {
                hasTelephoto = true
                
                // 망원 카메라의 실제 줌 범위 확인
                let minZoom = Double(telephoto.minAvailableVideoZoomFactor)
                let maxZoom = Double(telephoto.maxAvailableVideoZoomFactor)
                
                print("📱 망원 카메라 줌 범위: \(minZoom)x - \(maxZoom)x")
                
                // 망원 카메라가 2x를 지원하면 추가
                if minZoom <= 2.0 && maxZoom >= 2.0 {
                    levels.append(2.0)
                }
                
                // 망원 카메라가 3x를 지원하면 추가 (물리적 망원으로)
                if minZoom <= 3.0 && maxZoom >= 3.0 {
                    levels.append(3.0)
                }
            } else {
                // 망원 카메라가 없는 경우
                print("📱 물리적 망원 카메라 없음")
                
                // 현재 광각 카메라의 디지털 줌 범위 확인
                if let wideDevice = currentDevice {
                    let maxDigitalZoom = Double(wideDevice.maxAvailableVideoZoomFactor)
                    print("📱 광각 카메라 최대 디지털 줌: \(maxDigitalZoom)x")
                    
                    // 디지털 줌으로 2x 제공
                    if maxDigitalZoom >= 2.0 {
                        levels.append(2.0)
                    }
                    
                    // 디지털 줌으로 3x 제공 (망원 카메라가 없을 때만)
                    if maxDigitalZoom >= 3.0 {
                        levels.append(3.0)
                    }
                }
            }
        } else {
            // 전면 카메라는 줌 미지원 - 빈 배열 반환
            // levels는 빈 상태로 유지
        }
        
        // 정렬
        levels.sort()
        
        // ✅ 배율을 최대 3개로 제한
        if levels.count > 3 {
            levels = Array(levels.prefix(3))
        }
        
        print("📱 디바이스 카메라 구성:")
        print("   - 초광각: \(hasUltraWide ? "있음" : "없음")")
        print("   - 망원: \(hasTelephoto ? "있음" : "없음")")
        print("📱 최종 사용 가능한 줌 레벨: \(levels)")
        
        result(levels)
    }
}

// 카메라 미리보기를 위한 플랫폼 뷰 팩토리
class CameraPreviewFactory: NSObject, FlutterPlatformViewFactory {
    private let captureSession: AVCaptureSession
    
    init(captureSession: AVCaptureSession) {
        self.captureSession = captureSession
        super.init()
    }
    
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return CameraPreviewView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            captureSession: captureSession
        )
    }
    
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

// 미리보기 뷰 레이어 클래스
class PreviewView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        if let layer = layer as? AVCaptureVideoPreviewLayer {
            layer.videoGravity = .resizeAspectFill
            layer.connection?.videoOrientation = .portrait
            
            // ✅ 수정: 미러링 설정을 SwiftCameraPlugin.applyMirroringToAllConnections()에서만 처리
            // 중복 미러링 설정 제거로 경쟁 상태 방지
            print("🔧 PreviewView layoutSubviews - 미러링은 플러그인에서 통합 관리")
        }
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
}

// 카메라 미리보기 플랫폼 뷰
class CameraPreviewView: NSObject, FlutterPlatformView {
    private var _view: PreviewView
    
    init(frame: CGRect, viewIdentifier: Int64, arguments args: Any?, captureSession: AVCaptureSession) {
        _view = PreviewView(frame: frame)
        super.init()
        
        // 뷰 레이어 설정
        if let previewLayer = _view.layer as? AVCaptureVideoPreviewLayer {
            previewLayer.session = captureSession
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.connection?.videoOrientation = .portrait
            
            // ✅ 수정: 미러링 설정을 SwiftCameraPlugin.applyMirroringToAllConnections()에서만 처리
            // 중복 미러링 설정 제거로 경쟁 상태 방지
            print("🔧 CameraPreviewView 초기화 - 미러링은 플러그인에서 통합 관리")
        }
        
        _view.frame = frame
        _view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // 세션이 실행 중이 아니면 시작
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }
        }
    }
    
    func view() -> UIView {
        return _view
    }
}
