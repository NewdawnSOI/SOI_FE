import Flutter
import UIKit
import AVFoundation

// MARK: - SwiftCameraPlugin (Photo: AVCapturePhotoOutput as-is, Video: AVAssetWriter + *DataOutput)
public class SwiftCameraPlugin: NSObject,
    FlutterPlugin,
    AVCapturePhotoCaptureDelegate,
    AVCaptureVideoDataOutputSampleBufferDelegate,
    AVCaptureAudioDataOutputSampleBufferDelegate
{
    // MARK: Session & Outputs
    var captureSession: AVCaptureSession?
    var photoOutput: AVCapturePhotoOutput?
    var currentDevice: AVCaptureDevice?
    var flashMode: AVCaptureDevice.FlashMode = .off
    var isUsingFrontCamera: Bool = false
    var photoCaptureResult: FlutterResult?
    var currentZoomLevel: Double = 1.0

    // NOTE: MovieFileOutput is not used anymore for video; kept for compatibility
    var movieOutput: AVCaptureMovieFileOutput?

    var audioInput: AVCaptureDeviceInput?
    var methodChannel: FlutterMethodChannel?

    // MARK: Video (AVAssetWriter pipeline)
    let isMultiCamSupported: Bool = AVCaptureMultiCamSession.isMultiCamSupported
    enum ActiveCamera { case front, back }
    var activeCamera: ActiveCamera = .back

    var backVideoOutput: AVCaptureVideoDataOutput?
    var frontVideoOutput: AVCaptureVideoDataOutput? // only used when MultiCam
    var audioDataOutput: AVCaptureAudioDataOutput?

    var writer: AVAssetWriter?
    var writerVideoInput: AVAssetWriterInput?
    var writerAudioInput: AVAssetWriterInput?
    var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    var writerQueue = DispatchQueue(label: "com.soi.camera.writer")
    var isRecordingWithWriter = false
    var recordedVideoURL: URL?

    // Track last video timing/format for black-frame bridging (single-cam switch)
    var lastVideoSample: CMSampleBuffer?
    var lastVideoPTS: CMTime?
    var lastVideoFormatDesc: CMFormatDescription?

    // Timer reused from previous code for optional time limit
    var videoRecordingTimer: DispatchSourceTimer?

    // MARK: - Flutter registration
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.soi.camera", binaryMessenger: registrar.messenger())
        let instance = SwiftCameraPlugin()
        instance.methodChannel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)

        // init camera now
        instance.setupCamera()

        guard let captureSession = instance.captureSession else {
            print("⚠️ 카메라 세션이 초기화되지 않았습니다")
            return
        }
        registrar.register(
            CameraPreviewFactory(captureSession: captureSession),
            withId: "com.soi.camera/preview"
        )
    }

    // MARK: - Camera setup
    func setupCamera() {
        if isMultiCamSupported {
            captureSession = AVCaptureMultiCamSession()
            // MultiCam 세션은 프리셋을 지원하지 않음 - 각 카메라의 activeFormat으로 제어
            print("📱 MultiCam 지원 기기 - 프리셋 설정 생략")
        } else {
            captureSession = AVCaptureSession()
            captureSession?.sessionPreset = .high
            print("📱 일반 카메라 세션 - .high 프리셋 설정")
        }

        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            currentDevice = device
            beginSession()
        }
    }

    func beginSession() {
        guard let session = captureSession, let device = currentDevice else { return }
        do {
            // Video input (current camera)
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input) }

            // Photo output (kept as-is)
            photoOutput = AVCapturePhotoOutput()
            if let photoOutput = photoOutput, session.canAddOutput(photoOutput) {
                if #available(iOS 11.0, *) {
                    if photoOutput.availablePhotoPixelFormatTypes.contains(kCVPixelFormatType_32BGRA) {
                        photoOutput.setPreparedPhotoSettingsArray([
                            AVCapturePhotoSettings(format: [
                                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                            ])
                        ], completionHandler: nil)
                        print("🎨 Photo output color space set: sRGB (32BGRA)")
                    }
                }
                session.addOutput(photoOutput)
                if let connection = photoOutput.connection(with: .video), connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = false
                }
            }

            // ===== Video/Audio DATA OUTPUTS for AVAssetWriter =====
            session.beginConfiguration()
            if isMultiCamSupported, let multi = session as? AVCaptureMultiCamSession {
                // Front cam input in parallel
                if let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                    let frontInput = try AVCaptureDeviceInput(device: front)
                    if multi.canAddInput(frontInput) { multi.addInput(frontInput) }
                }
                // back video output
                let backOut = AVCaptureVideoDataOutput()
                backOut.alwaysDiscardsLateVideoFrames = true
                backOut.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.soi.camera.back.video"))
                if multi.canAddOutput(backOut) { multi.addOutput(backOut) }
                self.backVideoOutput = backOut

                // front video output
                let frontOut = AVCaptureVideoDataOutput()
                frontOut.alwaysDiscardsLateVideoFrames = true
                frontOut.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.soi.camera.front.video"))
                if multi.canAddOutput(frontOut) { multi.addOutput(frontOut) }
                self.frontVideoOutput = frontOut

                // audio data output
                let audioOut = AVCaptureAudioDataOutput()
                audioOut.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.soi.camera.audio"))
                if multi.canAddOutput(audioOut) { multi.addOutput(audioOut) }
                self.audioDataOutput = audioOut

            } else {
                // Single-cam: one video data output from current camera
                let vOut = AVCaptureVideoDataOutput()
                vOut.alwaysDiscardsLateVideoFrames = true
                vOut.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.soi.camera.video"))
                if session.canAddOutput(vOut) { session.addOutput(vOut) }
                self.backVideoOutput = vOut

                // Ensure audio device input + audio data output
                try attachAudioInputIfNeeded()
                let audioOut = AVCaptureAudioDataOutput()
                audioOut.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.soi.camera.audio"))
                if session.canAddOutput(audioOut) { session.addOutput(audioOut) }
                self.audioDataOutput = audioOut
            }
            session.commitConfiguration()

            // Start session
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.applyMirroringToAllConnections()
                    print("🔧 Session started & mirroring applied")
                }
            }
        } catch {
            print("카메라 세션 설정 오류: \(error)")
        }
    }

    // MARK: Flutter method handling
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

    // MARK: - Init & Photo pipeline (unchanged)
    func initCamera(result: @escaping FlutterResult) {
        if captureSession == nil { setupCamera() }
        result("Camera initialized")
    }

    func takePicture(result: @escaping FlutterResult) {
        guard let photoOutput = self.photoOutput else {
            result(FlutterError(code: "NO_PHOTO_OUTPUT", message: "Photo output not available", details: nil))
            return
        }
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        if #available(iOS 13.0, *) {
            let desired: AVCapturePhotoOutput.QualityPrioritization = .quality
            let maxSupported = photoOutput.maxPhotoQualityPrioritization
            settings.photoQualityPrioritization = (desired.rawValue <= maxSupported.rawValue) ? desired : maxSupported
        }
        if currentDevice?.position == .front { print("🔧 Front camera photo settings applied") }
        photoCaptureResult = result
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            photoCaptureResult?(FlutterError(code: "CAPTURE_ERROR", message: error.localizedDescription, details: nil))
            return
        }
        guard let data = photo.fileDataRepresentation(), let uiImage = UIImage(data: data) else {
            photoCaptureResult?(FlutterError(code: "NO_IMAGE_DATA", message: "Could not get image data", details: nil))
            return
        }
        guard let jpg = uiImage.jpegData(compressionQuality: 0.9) else {
            photoCaptureResult?(FlutterError(code: "IMAGE_PROCESSING_ERROR", message: "JPEG conversion failed", details: nil))
            return
        }
        let temp = NSTemporaryDirectory()
        let path = temp + "/\(UUID().uuidString).jpg"
        let url = URL(fileURLWithPath: path)
        do { try jpg.write(to: url); photoCaptureResult?(path) } catch {
            photoCaptureResult?(FlutterError(code: "FILE_SAVE_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    // MARK: - Video recording (AVAssetWriter)
    func startVideoRecording(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let session = captureSession else {
            result(FlutterError(code: "SESSION_ERROR", message: "Camera session is not initialized", details: nil))
            return
        }
        if isRecordingWithWriter {
            result(FlutterError(code: "ALREADY_RECORDING", message: "Recording already in progress", details: nil))
            return
        }
        let args = call.arguments as? [String: Any]
        let requestedDurationMs = args?["maxDurationMs"] as? Int ?? 30_000
        let durationSeconds = max(1.0, min(Double(requestedDurationMs) / 1000.0, 30.0))

        let tempDir = NSTemporaryDirectory()
        let fileURL = URL(fileURLWithPath: tempDir).appendingPathComponent("\(UUID().uuidString).mov")
        recordedVideoURL = fileURL

        do {
            try prepareWriter(at: fileURL, sourceFormat: nil) // actual session start happens at first frame
        } catch {
            result(FlutterError(code: "WRITER_ERROR", message: "Failed to prepare writer", details: error.localizedDescription))
            return
        }
        isRecordingWithWriter = true

        startVideoTimeoutTimer(duration: durationSeconds + 0.5)
        if !session.isRunning { DispatchQueue.global(qos: .userInitiated).async { session.startRunning() } }
        result(true)
    }

    func stopVideoRecording(result: @escaping FlutterResult) {
        guard isRecordingWithWriter else {
            result(FlutterError(code: "NO_ACTIVE_RECORDING", message: "No active video recording to stop", details: nil))
            return
        }
        stopVideoTimeoutTimer()
        finishWriter { [weak self] url, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.methodChannel?.invokeMethod("onVideoError", arguments: ["message": error.localizedDescription])
                }
                result(FlutterError(code: "VIDEO_RECORDING_ERROR", message: error.localizedDescription, details: nil))
                return
            }
            result(url?.path ?? "")
            if let path = url?.path {
                DispatchQueue.main.async {
                    self?.methodChannel?.invokeMethod("onVideoRecorded", arguments: ["path": path])
                }
            }
        }
    }

    func cancelVideoRecording(result: @escaping FlutterResult) {
        guard isRecordingWithWriter else {
            result(FlutterError(code: "NO_ACTIVE_RECORDING", message: "No active video recording to cancel", details: nil))
            return
        }
        stopVideoTimeoutTimer()
        finishWriter { [weak self] url, _ in
            if let url = url { try? FileManager.default.removeItem(at: url) }
            result("")
        }
    }

    // MARK: - Writer helpers
    private func prepareWriter(at url: URL, sourceFormat: CMFormatDescription?) throws {
        writer = try AVAssetWriter(outputURL: url, fileType: .mov)

        // Dimensions: use source if known, else default 1080x1920
        let dims: CMVideoDimensions
        if let fmt = sourceFormat {
            dims = CMVideoFormatDescriptionGetDimensions(fmt)
        } else {
            dims = CMVideoDimensions(width: 1080, height: 1920)
        }

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(dims.width),
            AVVideoHeightKey: Int(dims.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 8_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        let vIn = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        vIn.expectsMediaDataInRealTime = true
        
        // Portrait 비디오를 위한 transform 설정 (90도 시계방향 회전)
        // iOS 카메라는 landscape로 캡처하므로 portrait로 보이려면 90도 회전 필요
        vIn.transform = CGAffineTransform(rotationAngle: .pi / 2)
        
        writerVideoInput = vIn
        writer?.add(vIn)

        // Pixel buffer adaptor (used for black frames bridging)
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(dims.width),
            kCVPixelBufferHeightKey as String: Int(dims.height)
        ]
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: vIn,
                                                                  sourcePixelBufferAttributes: attrs)

        // Audio input
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey: 128_000
        ]
        let aIn = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        aIn.expectsMediaDataInRealTime = true
        writerAudioInput = aIn
        writer?.add(aIn)

        lastVideoSample = nil
        lastVideoPTS = nil
        lastVideoFormatDesc = sourceFormat
    }

    private func startWriterSessionIfNeeded(with sampleBuffer: CMSampleBuffer) {
        guard let writer = writer, writer.status == .unknown else { return }
        let ts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        writer.startWriting()
        writer.startSession(atSourceTime: ts)
        lastVideoPTS = ts
    }

    private func finishWriter(completion: @escaping (URL?, Error?) -> Void) {
        guard let writer = writer else { completion(nil, nil); return }
        isRecordingWithWriter = false
        writerVideoInput?.markAsFinished()
        writerAudioInput?.markAsFinished()
        writer.finishWriting { [weak self] in
            let url = self?.recordedVideoURL
            let err = (writer.status == .failed) ? writer.error : nil
            self?.writer = nil
            self?.writerVideoInput = nil
            self?.writerAudioInput = nil
            self?.pixelBufferAdaptor = nil
            self?.lastVideoSample = nil
            self?.lastVideoPTS = nil
            completion(url, err)
        }
    }

    // Add ~150ms of black frames to smooth single-cam input switch
    private func appendBlackFramesBridge(durationMs: Int = 150) {
        guard !isMultiCamSupported, isRecordingWithWriter,
              let adaptor = pixelBufferAdaptor,
              let vIn = writerVideoInput,
              let lastPTS = lastVideoPTS else { return }

        // 30 fps bridge
        let fps: Int32 = 30
        let frameDuration = CMTime(value: 1, timescale: fps)
        let frames = max(1, (durationMs * Int(fps)) / 1000)

        for i in 1...frames {
            autoreleasepool {
                var pb: CVPixelBuffer?
                let attrs: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: adaptor.sourcePixelBufferAttributes?[kCVPixelBufferWidthKey as String] as? Int ?? 1080,
                    kCVPixelBufferHeightKey as String: adaptor.sourcePixelBufferAttributes?[kCVPixelBufferHeightKey as String] as? Int ?? 1920
                ]
                CVPixelBufferCreate(kCFAllocatorDefault,
                                    attrs[kCVPixelBufferWidthKey as String] as! Int,
                                    attrs[kCVPixelBufferHeightKey as String] as! Int,
                                    kCVPixelFormatType_32BGRA,
                                    attrs as CFDictionary,
                                    &pb)
                if let buffer = pb {
                    CVPixelBufferLockBaseAddress(buffer, [])
                    if let base = CVPixelBufferGetBaseAddress(buffer) {
                        memset(base, 0, CVPixelBufferGetDataSize(buffer)) // black
                    }
                    CVPixelBufferUnlockBaseAddress(buffer, [])

                    let pts = CMTimeAdd(lastPTS, CMTimeMultiply(frameDuration, multiplier: Int32(i)))
                    while !vIn.isReadyForMoreMediaData { usleep(1000) }
                    adaptor.append(buffer, withPresentationTime: pts)
                    lastVideoPTS = pts
                }
            }
        }
    }

    // MARK: - SampleBuffer delegates
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRecordingWithWriter, let writer = writer else { return }
        let desc = CMSampleBufferGetFormatDescription(sampleBuffer)!
        let mediaType = CMFormatDescriptionGetMediaType(desc)

        if mediaType == kCMMediaType_Video {
            // MultiCam: only append from active camera
            if isMultiCamSupported {
                let isFrontFeed = (output === frontVideoOutput)
                if !((activeCamera == .front && isFrontFeed) || (activeCamera == .back && !isFrontFeed)) {
                    return
                }
            }
            if writer.status == .unknown { startWriterSessionIfNeeded(with: sampleBuffer) }
            if writer.status == .writing, writerVideoInput?.isReadyForMoreMediaData == true {
                writerVideoInput?.append(sampleBuffer)
                lastVideoSample = sampleBuffer
                lastVideoPTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                lastVideoFormatDesc = desc
            }
        } else if mediaType == kCMMediaType_Audio {
            if writer.status == .writing, writerAudioInput?.isReadyForMoreMediaData == true {
                writerAudioInput?.append(sampleBuffer)
            }
        }
    }

    // MARK: - Camera switching (seamless when MultiCam)
    func switchCamera(result: @escaping FlutterResult) {
        guard let captureSession = captureSession else {
            result(FlutterError(code: "NO_CAMERA", message: "No camera session", details: nil))
            return
        }

        // MultiCam 녹화 중: activeCamera만 토글 (입력은 그대로 유지)
        if isRecordingWithWriter && isMultiCamSupported {
            isUsingFrontCamera.toggle()
            activeCamera = isUsingFrontCamera ? .front : .back
            
            // 프리뷰 연결 전환
            updatePreviewConnection()
            
            // 프리뷰 미러링 업데이트
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self else { return }
                self.applyMirroringToAllConnections()
                print("🔁 MultiCam live switch → \(self.isUsingFrontCamera ? "front" : "back")")
            }
            
            result("Camera switched (MultiCam, seamless)")
            return
        }

        // Fallback: single-cam (replace input). Writer keeps running → same file
        // --- original-like logic below ---

        // Find current video input
        var videoInput: AVCaptureDeviceInput?
        for input in captureSession.inputs {
            if let deviceInput = input as? AVCaptureDeviceInput, deviceInput.device.hasMediaType(.video) {
                videoInput = deviceInput
                break
            }
        }
        guard let currentInput = videoInput else {
            result(FlutterError(code: "NO_CAMERA", message: "No current camera input", details: nil))
            return
        }

        isUsingFrontCamera.toggle()
        let newPosition: AVCaptureDevice.Position = isUsingFrontCamera ? .front : .back
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            isUsingFrontCamera.toggle()
            result(FlutterError(code: "NO_DEVICE", message: "Target camera not available", details: nil))
            return
        }

        captureSession.beginConfiguration()
        captureSession.removeInput(currentInput)
        do {
            currentDevice = newDevice
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            if captureSession.canAddInput(newInput) { captureSession.addInput(newInput) }
            else {
                captureSession.addInput(currentInput)
                isUsingFrontCamera.toggle()
                captureSession.commitConfiguration()
                result(FlutterError(code: "ADD_INPUT_FAILED", message: "Cannot add new camera input", details: nil))
                return
            }
        } catch {
            captureSession.addInput(currentInput)
            isUsingFrontCamera.toggle()
            captureSession.commitConfiguration()
            result(FlutterError(code: "SWITCH_ERROR", message: error.localizedDescription, details: nil))
            return
        }
        captureSession.commitConfiguration()

        // Re-apply mirroring for preview
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.applyMirroringToAllConnections()
        }

        // Bridge tiny gap with black frames so the file feels continuous
        appendBlackFramesBridge(durationMs: 150)

        result("Camera switched")
    }
    
    // MARK: - MultiCam 프리뷰 전환 (사용하지 않음 - 입력 교체 방식으로 대체)
    private func updatePreviewConnection() {
        guard let captureSession = captureSession, isMultiCamSupported else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 프리뷰 레이어의 연결 찾기 및 업데이트
            for output in captureSession.outputs {
                for connection in output.connections {
                    if let previewLayer = connection.videoPreviewLayer {
                        captureSession.beginConfiguration()
                        
                        // 타겟 카메라 포지션
                        let targetPosition: AVCaptureDevice.Position = self.isUsingFrontCamera ? .front : .back
                        
                        // 타겟 카메라 입력 찾기
                        var targetInput: AVCaptureDeviceInput?
                        for input in captureSession.inputs {
                            if let deviceInput = input as? AVCaptureDeviceInput,
                               deviceInput.device.hasMediaType(.video),
                               deviceInput.device.position == targetPosition {
                                targetInput = deviceInput
                                break
                            }
                        }
                        
                        if let targetInput = targetInput,
                           let videoPort = targetInput.ports(for: .video,
                                                            sourceDeviceType: targetInput.device.deviceType,
                                                            sourceDevicePosition: targetInput.device.position).first {
                            
                            // 기존 연결 제거
                            captureSession.removeConnection(connection)
                            
                            // 새 연결 생성
                            let newConnection = AVCaptureConnection(inputPort: videoPort, videoPreviewLayer: previewLayer)
                            if captureSession.canAddConnection(newConnection) {
                                captureSession.addConnection(newConnection)
                                newConnection.videoOrientation = .portrait
                                print("✅ 프리뷰 연결 전환: \(targetPosition == .front ? "전면" : "후면")")
                            }
                        }
                        
                        captureSession.commitConfiguration()
                        return
                    }
                }
            }
        }
    }

    // MARK: - Flash / Zoom / Pause / Resume / Dispose / Optimize (mostly unchanged)
    func setFlash(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any], let isOn = args["isOn"] as? Bool else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing or invalid isOn parameter", details: nil))
            return
        }
        flashMode = isOn ? .on : .off
        result("Flash set to \(isOn ? "on" : "off")")
    }

    func setZoom(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any], let zoomValue = args["zoomValue"] as? Double else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing or invalid zoomValue parameter", details: nil))
            return
        }
        guard let captureSession = captureSession else {
            result(FlutterError(code: "NO_SESSION", message: "No capture session available", details: nil))
            return
        }
        if isUsingFrontCamera { result("Front camera does not support zoom"); return }
        currentZoomLevel = zoomValue

        let hasTelephoto = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back) != nil
        let targetType: AVCaptureDevice.DeviceType
        let digitalFactor: CGFloat
        if zoomValue < 0.75 {
            targetType = .builtInUltraWideCamera
            digitalFactor = CGFloat(zoomValue * 2.0)
        } else if zoomValue < 1.5 {
            targetType = .builtInWideAngleCamera
            digitalFactor = CGFloat(zoomValue)
        } else if zoomValue < 2.5 && hasTelephoto {
            targetType = .builtInTelephotoCamera
            digitalFactor = 1.0
        } else if zoomValue >= 3.0 && hasTelephoto {
            targetType = .builtInTelephotoCamera
            digitalFactor = CGFloat(zoomValue / 2.0)
        } else {
            targetType = .builtInWideAngleCamera
            digitalFactor = CGFloat(zoomValue)
        }
        guard let newDevice = AVCaptureDevice.default(targetType, for: .video, position: .back) else {
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

        if newDevice != currentDevice {
            captureSession.beginConfiguration()
            if let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput { captureSession.removeInput(currentInput) }
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                if captureSession.canAddInput(newInput) {
                    captureSession.addInput(newInput)
                    currentDevice = newDevice
                }
                try newDevice.lockForConfiguration()
                let maxZoom = newDevice.activeFormat.videoMaxZoomFactor
                let finalZoom = min(digitalFactor, maxZoom)
                newDevice.videoZoomFactor = finalZoom
                newDevice.unlockForConfiguration()
            } catch {
                result(FlutterError(code: "CAMERA_SWITCH_ERROR", message: error.localizedDescription, details: nil))
                captureSession.commitConfiguration()
                return
            }
            captureSession.commitConfiguration()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.applyMirroringToAllConnections() }
            result("Zoom set to \(zoomValue)x with camera switch")
        } else {
            do {
                try currentDevice?.lockForConfiguration()
                let maxZoom = currentDevice?.activeFormat.videoMaxZoomFactor ?? 1.0
                let finalZoom = min(digitalFactor, maxZoom)
                currentDevice?.videoZoomFactor = finalZoom
                currentDevice?.unlockForConfiguration()
                result("Zoom adjusted to \(zoomValue)x")
            } catch {
                result(FlutterError(code: "ZOOM_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }

    func pauseCamera(result: @escaping FlutterResult) {
        guard let captureSession = captureSession else {
            result(FlutterError(code: "SESSION_ERROR", message: "Camera session is not initialized", details: nil))
            return
        }
        if captureSession.isRunning { captureSession.stopRunning() }
        result("Camera paused")
    }

    func resumeCamera(result: @escaping FlutterResult) {
        guard let captureSession = captureSession else {
            result(FlutterError(code: "SESSION_ERROR", message: "Camera session is not initialized", details: nil))
            return
        }
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.applyMirroringToAllConnections()
                    print("🔧 Session resumed & mirroring applied")
                }
            }
        }
        result("Camera resumed")
    }

    func disposeCamera(result: @escaping FlutterResult) {
        guard let captureSession = captureSession else {
            result(FlutterError(code: "SESSION_ERROR", message: "Camera session is not initialized", details: nil))
            return
        }
        // Ensure writer finishes
        if isRecordingWithWriter { stopVideoTimeoutTimer(); finishWriter { _,_ in } }
        captureSession.stopRunning()
        result("Camera disposed")
    }

    func optimizeCamera(result: @escaping FlutterResult) {
        guard let currentDevice = currentDevice else {
            result(FlutterError(code: "NO_CAMERA", message: "No camera available", details: nil))
            return
        }
        do {
            try currentDevice.lockForConfiguration()
            if currentDevice.isFocusModeSupported(.continuousAutoFocus) { currentDevice.focusMode = .continuousAutoFocus }
            if currentDevice.isExposureModeSupported(.continuousAutoExposure) { currentDevice.exposureMode = .continuousAutoExposure }
            currentDevice.unlockForConfiguration()
            result("Camera optimized")
        } catch {
            result(FlutterError(code: "OPTIMIZATION_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    func getAvailableZoomLevels(result: @escaping FlutterResult) {
        var levels: [Double] = []
        var hasUltraWide = false
        var hasTelephoto = false
        if !isUsingFrontCamera {
            if AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) != nil { hasUltraWide = true; levels.append(0.5) }
            levels.append(1.0)
            let telephoto = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
            if let tele = telephoto {
                hasTelephoto = true
                let minZ = Double(tele.minAvailableVideoZoomFactor)
                let maxZ = Double(tele.maxAvailableVideoZoomFactor)
                if minZ <= 2.0 && maxZ >= 2.0 { levels.append(2.0) }
                if minZ <= 3.0 && maxZ >= 3.0 { levels.append(3.0) }
            } else if let wide = currentDevice {
                let maxDigital = Double(wide.maxAvailableVideoZoomFactor)
                if maxDigital >= 2.0 { levels.append(2.0) }
                if maxDigital >= 3.0 { levels.append(3.0) }
            }
        }
        levels.sort()
        if levels.count > 3 { levels = Array(levels.prefix(3)) }
        print("📱 Device cameras → ultraWide: \(hasUltraWide), tele: \(hasTelephoto), levels: \(levels)")
        result(levels)
    }

    // MARK: - Helpers reused from original
    private func attachAudioInputIfNeeded() throws {
        guard let captureSession = captureSession else { return }
        if audioInput != nil { return }
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

    private func startVideoTimeoutTimer(duration: TimeInterval) {
        stopVideoTimeoutTimer()
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now() + duration)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            if self.isRecordingWithWriter {
                self.stopVideoRecording { _ in }
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

    // MARK: - Mirroring policy (preview only)
    func applyMirroringToAllConnections() {
        guard let captureSession = captureSession else { return }
        let isFront = (activeCamera == .front) || isUsingFrontCamera
        for output in captureSession.outputs {
            if output is AVCapturePhotoOutput || output is AVCaptureMovieFileOutput || output is AVCaptureVideoDataOutput {
                for connection in output.connections {
                    if connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false
                        connection.isVideoMirrored = false // never mirror actual capture
                    }
                }
            } else {
                for connection in output.connections {
                    if connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false
                        connection.isVideoMirrored = isFront // preview only
                    }
                }
            }
        }
    }
}

// MARK: - Preview view classes
class CameraPreviewFactory: NSObject, FlutterPlatformViewFactory {
    private let captureSession: AVCaptureSession
    init(captureSession: AVCaptureSession) {
        self.captureSession = captureSession
        super.init()
    }
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return CameraPreviewView(frame: frame, viewIdentifier: viewId, arguments: args, captureSession: captureSession)
    }
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
}

class PreviewView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        if let layer = layer as? AVCaptureVideoPreviewLayer {
            layer.videoGravity = .resizeAspectFill
            layer.connection?.videoOrientation = .portrait
            print("🔧 PreviewView layoutSubviews — mirroring handled by plugin")
        }
    }
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
}

class CameraPreviewView: NSObject, FlutterPlatformView {
    private var _view: PreviewView
    init(frame: CGRect, viewIdentifier: Int64, arguments args: Any?, captureSession: AVCaptureSession) {
        _view = PreviewView(frame: frame)
        super.init()
        if let previewLayer = _view.layer as? AVCaptureVideoPreviewLayer {
            previewLayer.session = captureSession
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.connection?.videoOrientation = .portrait
            print("🔧 CameraPreviewView init — preview mirroring handled by plugin")
        }
        _view.frame = frame
        _view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { captureSession.startRunning() }
        }
    }
    func view() -> UIView { _view }
}
