import Flutter
import UIKit
import AVFoundation

// MARK: - Flutter Plugin Entry Point
public final class SwiftCameraPlugin: NSObject, FlutterPlugin {
    private static let channelName = "com.soi.camera"

    private let sessionManager = CameraSessionManager()
    private var channel: FlutterMethodChannel?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftCameraPlugin()
        let methodChannel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        instance.channel = methodChannel
        instance.sessionManager.delegate = instance
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        registrar.register(
            CameraPreviewFactory(sessionManager: instance.sessionManager),
            withId: "com.soi.camera/preview"
        )
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initCamera":
            sessionManager.ensureConfigured { outcome in
                DispatchQueue.main.async {
                    switch outcome {
                    case .success:
                        result(true)
                    case .failure(let error):
                        result(FlutterError(code: "INIT_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "takePicture":
            sessionManager.capturePhoto { outcome in
                DispatchQueue.main.async {
                    switch outcome {
                    case .success(let path):
                        result(path)
                    case .failure(let error):
                        result(FlutterError(code: "CAPTURE_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "switchCamera":
            sessionManager.switchCamera { outcome in
                DispatchQueue.main.async {
                    switch outcome {
                    case .success:
                        result("Camera switched")
                    case .failure(let error):
                        result(FlutterError(code: "SWITCH_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "setFlash":
            guard let args = call.arguments as? [String: Any],
                  let isOn = args["isOn"] as? Bool else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing isOn", details: nil))
                return
            }
            sessionManager.setFlash(isOn: isOn) { outcome in
                DispatchQueue.main.async {
                    switch outcome {
                    case .success:
                        result("Flash updated")
                    case .failure(let error):
                        result(FlutterError(code: "FLASH_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "setZoom":
            guard let args = call.arguments as? [String: Any],
                  let zoomValue = args["zoomValue"] as? Double else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing zoomValue", details: nil))
                return
            }
            sessionManager.setZoom(to: zoomValue) { outcome in
                DispatchQueue.main.async {
                    switch outcome {
                    case .success:
                        result("Zoom updated")
                    case .failure(let error):
                        result(FlutterError(code: "ZOOM_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "setBrightness":
            guard let args = call.arguments as? [String: Any],
                  let value = args["value"] as? Double else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing value", details: nil))
                return
            }
            sessionManager.setBrightness(value) { outcome in
                DispatchQueue.main.async {
                    switch outcome {
                    case .success:
                        result("Brightness updated")
                    case .failure(let error):
                        result(FlutterError(code: "BRIGHTNESS_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "getAvailableZoomLevels":
            sessionManager.availableZoomLevels { levels in
                DispatchQueue.main.async {
                    result(levels)
                }
            }

        case "optimizeCamera":
            sessionManager.optimizeForCapture { outcome in
                DispatchQueue.main.async {
                    switch outcome {
                    case .success:
                        result("Camera optimized")
                    case .failure(let error):
                        result(FlutterError(code: "OPTIMIZE_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "pauseCamera":
            sessionManager.pauseSession()
            result("Camera paused")

        case "resumeCamera":
            sessionManager.resumeSession { outcome in
                DispatchQueue.main.async {
                    switch outcome {
                    case .success:
                        result("Camera resumed")
                    case .failure(let error):
                        result(FlutterError(code: "RESUME_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "disposeCamera":
            sessionManager.dispose()
            result("Camera disposed")

        case "startVideoRecording":
            let durationMs = (call.arguments as? [String: Any])?["maxDurationMs"] as? Int
            sessionManager.startRecording(maxDurationMs: durationMs) { outcome in
                DispatchQueue.main.async {
                    switch outcome {
                    case .success:
                        result(true)
                    case .failure(let error):
                        result(FlutterError(code: "RECORDING_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "stopVideoRecording":
            sessionManager.stopRecording { outcome in
                DispatchQueue.main.async {
                    switch outcome {
                    case .success(let path):
                        result(path)
                    case .failure(let error):
                        result(FlutterError(code: "STOP_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "cancelVideoRecording":
            sessionManager.cancelRecording { outcome in
                DispatchQueue.main.async {
                    switch outcome {
                    case .success:
                        result("")
                    case .failure(let error):
                        result(FlutterError(code: "CANCEL_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "supportsLiveSwitch":
            result(sessionManager.supportsLiveSwitch)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

// MARK: - Delegate Bridge
extension SwiftCameraPlugin: CameraSessionManagerDelegate {
    fileprivate func cameraSessionManager(_ manager: CameraSessionManager, didFinishRecording path: String) {
        channel?.invokeMethod("onVideoRecorded", arguments: ["path": path])
    }

    fileprivate func cameraSessionManager(_ manager: CameraSessionManager, didFailRecording error: Error) {
        channel?.invokeMethod("onVideoError", arguments: ["message": error.localizedDescription])
    }
}

// MARK: - Camera Session Manager
fileprivate protocol CameraSessionManagerDelegate: AnyObject {
    func cameraSessionManager(_ manager: CameraSessionManager, didFinishRecording path: String)
    func cameraSessionManager(_ manager: CameraSessionManager, didFailRecording error: Error)
}

fileprivate enum CameraSessionError: LocalizedError {
    case deviceUnavailable
    case configurationFailed
    case alreadyRecording
    case notRecording
    case cannotSwitchWhileRecording

    var errorDescription: String? {
        switch self {
        case .deviceUnavailable:
            return "Camera device is unavailable"
        case .configurationFailed:
            return "Failed to configure camera session"
        case .alreadyRecording:
            return "Video recording already in progress"
        case .notRecording:
            return "No active recording"
        case .cannotSwitchWhileRecording:
            return "Cannot switch camera while recording"
        }
    }
}

fileprivate final class CameraSessionManager: NSObject, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate {
    weak var delegate: CameraSessionManagerDelegate?

    private let sessionQueue = DispatchQueue(label: "com.soi.camera.session")
    private let captureSession = AVCaptureSession()

    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var deviceCache: [AVCaptureDevice.Position: AVCaptureDevice] = [:]

    private var isConfigured = false
    private var currentPosition: AVCaptureDevice.Position = .back
    private var flashMode: AVCaptureDevice.FlashMode = .auto
    private var photoCompletion: ((Result<String, Error>) -> Void)?
    private var recordingCompletion: ((Result<String, Error>) -> Void)?
    private var recordingTimer: DispatchSourceTimer?
    private var currentMovieURL: URL?
    private var isCancellingRecording = false

    var supportsLiveSwitch: Bool {
        availablePositions.count > 1
    }

    func ensureConfigured(completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async {
            if self.isConfigured {
                self.startSessionIfNeeded()
                completion(.success(()))
                return
            }

            do {
                try self.configureSession()
                self.isConfigured = true
                self.startSessionIfNeeded()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func capturePhoto(completion: @escaping (Result<String, Error>) -> Void) {
        ensureConfigured { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                self.sessionQueue.async {
                    guard self.photoOutput.connection(with: .video) != nil else {
                        completion(.failure(CameraSessionError.configurationFailed))
                        return
                    }

                    let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
                    if self.photoOutput.supportedFlashModes.contains(self.flashMode) {
                        settings.flashMode = self.flashMode
                    }

                    self.photoCompletion = completion
                    self.photoOutput.capturePhoto(with: settings, delegate: self)
                }
            }
        }
    }

    // 🔥 수정된 카메라 전환 로직 - 녹화 중에도 가능하도록
    func switchCamera(completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async {
            // ✅ 세션이 실행 중인지만 확인, 녹화 상태는 체크하지 않음
            guard self.captureSession.isRunning else {
                completion(.failure(CameraSessionError.configurationFailed))
                return
            }

            let target: AVCaptureDevice.Position = (self.currentPosition == .back) ? .front : .back
            let previousZoom = self.videoInput?.device.videoZoomFactor ?? 1.0

            do {
                // ✅ 녹화 중이라면 configuration 없이 직접 input 교체
                if self.movieOutput.isRecording {
                    try self.replaceVideoInputWhileRecording(position: target, desiredZoomFactor: previousZoom)
                } else {
                    try self.replaceVideoInput(position: target, desiredZoomFactor: previousZoom)
                }
                
                // ✅ 연결 설정 업데이트 (미러링 등)
                self.updateConnectionMirroring()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func setFlash(isOn: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async {
            self.flashMode = isOn ? .on : .off
            completion(.success(()))
        }
    }

    func setZoom(to value: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async {
            guard let device = self.videoInput?.device else {
                completion(.failure(CameraSessionError.deviceUnavailable))
                return
            }
            do {
                try device.lockForConfiguration()
                let minValue = max(1.0, value)
                let clamped = min(Double(device.activeFormat.videoMaxZoomFactor), minValue)
                device.videoZoomFactor = CGFloat(clamped)
                device.unlockForConfiguration()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func setBrightness(_ value: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async {
            guard let device = self.videoInput?.device else {
                completion(.failure(CameraSessionError.deviceUnavailable))
                return
            }
            do {
                try device.lockForConfiguration()
                let bias = max(min(Float(value), device.maxExposureTargetBias), device.minExposureTargetBias)
                device.setExposureTargetBias(bias) { _ in }
                device.unlockForConfiguration()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func availableZoomLevels(completion: @escaping ([Double]) -> Void) {
        sessionQueue.async {
            guard let device = self.videoInput?.device else {
                completion([1.0])
                return
            }

            let minZoom = Double(device.minAvailableVideoZoomFactor)
            let maxZoom = Double(device.activeFormat.videoMaxZoomFactor)

            // Define preferred zoom levels in priority order
            let preferredLevels: [Double] = [0.5, 1.0, 2.0, 3.0, 5.0]

            // Filter to only include levels within the device's supported range
            let supportedLevels = preferredLevels.filter { level in
                level >= minZoom && level <= maxZoom
            }

            // Ensure we have at least the min zoom level
            var finalLevels = Set(supportedLevels)
            finalLevels.insert(minZoom)

            // Return up to 3 levels, sorted
            completion(Array(finalLevels.sorted().prefix(3)))
        }
    }

    func optimizeForCapture(completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async {
            guard let device = self.videoInput?.device else {
                completion(.failure(CameraSessionError.deviceUnavailable))
                return
            }
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                }
                device.unlockForConfiguration()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func pauseSession() {
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }

    func resumeSession(completion: @escaping (Result<Void, Error>) -> Void) {
        ensureConfigured { outcome in
            completion(outcome)
        }
    }

    func dispose() {
        sessionQueue.sync {
            recordingTimer?.cancel()
            recordingTimer = nil
            if captureSession.isRunning { captureSession.stopRunning() }
            captureSession.inputs.forEach { captureSession.removeInput($0) }
            captureSession.outputs.forEach { captureSession.removeOutput($0) }
            videoInput = nil
            audioInput = nil
            isConfigured = false
            currentMovieURL = nil
        }
    }

    // 🔥 수정된 녹화 시작 로직 - 전면 카메라 지원 강화
    func startRecording(maxDurationMs: Int?, completion: @escaping (Result<Void, Error>) -> Void) {
        ensureConfigured { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                self.sessionQueue.async {
                    guard !self.movieOutput.isRecording else {
                        completion(.failure(CameraSessionError.alreadyRecording))
                        return
                    }

                    // ✅ 비디오 연결이 있는지 확인
                    guard let connection = self.movieOutput.connection(with: .video) else {
                        completion(.failure(CameraSessionError.configurationFailed))
                        return
                    }

                    // ✅ 연결 설정 (orientation과 mirroring)
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                    
                    // ✅ 전면 카메라일 경우 미러링 설정
                    if connection.isVideoMirroringSupported {
                        connection.isVideoMirrored = (self.currentPosition == .front)
                    }
                    
                    // ✅ 비디오 안정화 설정 (가능한 경우)
                    if connection.isVideoStabilizationSupported {
                        connection.preferredVideoStabilizationMode = .auto
                    }

                    let url = self.temporaryURL(extension: "mov")
                    self.currentMovieURL = url
                    self.isCancellingRecording = false

                    self.movieOutput.startRecording(to: url, recordingDelegate: self)
                    self.startRecordingTimerIfNeeded(maxDurationMs: maxDurationMs)
                    completion(.success(()))
                }
            }
        }
    }

    func stopRecording(completion: @escaping (Result<String, Error>) -> Void) {
        sessionQueue.async {
            guard self.movieOutput.isRecording else {
                completion(.failure(CameraSessionError.notRecording))
                return
            }
            self.recordingCompletion = completion
            self.isCancellingRecording = false
            self.movieOutput.stopRecording()
        }
    }

    func cancelRecording(completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async {
            guard self.movieOutput.isRecording else {
                completion(.success(()))
                return
            }
            self.isCancellingRecording = true
            self.recordingCompletion = { result in
                switch result {
                case .success:
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            self.movieOutput.stopRecording()
        }
    }

    func registerPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        layer.videoGravity = .resizeAspectFill
        layer.session = captureSession
        ensureConfigured { _ in }
    }

    // MARK: - Private Helpers
    private func configureSession() throws {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high

        try replaceVideoInput(position: currentPosition, desiredZoomFactor: 1.0)

        // ✅ 오디오 입력 추가 (비디오 녹화에 필수)
        if audioInput == nil, let audioDevice = AVCaptureDevice.default(for: .audio) {
            let input = try AVCaptureDeviceInput(device: audioDevice)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                audioInput = input
            }
        }

        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }

        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
            
            // ✅ MovieOutput 기본 설정
            if let connection = movieOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
            }
        }

        captureSession.commitConfiguration()
    }

    // ✅ 일반 비디오 입력 교체 (녹화 중이 아닐 때)
    private func replaceVideoInput(position: AVCaptureDevice.Position, desiredZoomFactor: CGFloat) throws {
        guard let device = cameraDevice(position: position) else {
            throw CameraSessionError.deviceUnavailable
        }

        let newInput = try AVCaptureDeviceInput(device: device)

        captureSession.beginConfiguration()
        if let existing = videoInput {
            captureSession.removeInput(existing)
        }

        guard captureSession.canAddInput(newInput) else {
            captureSession.commitConfiguration()
            throw CameraSessionError.configurationFailed
        }

        captureSession.addInput(newInput)
        captureSession.commitConfiguration()

        applyPreferredConfiguration(to: device, matching: desiredZoomFactor)

        videoInput = newInput
        currentPosition = position
    }

    // 🔥 새로운 메서드 - 녹화 중 비디오 입력 교체
    private func replaceVideoInputWhileRecording(position: AVCaptureDevice.Position, desiredZoomFactor: CGFloat) throws {
        guard let device = cameraDevice(position: position) else {
            throw CameraSessionError.deviceUnavailable
        }

        let newInput = try AVCaptureDeviceInput(device: device)

        // ✅ 녹화 중에는 beginConfiguration을 호출하지 않음
        // 대신 직접 input만 교체
        if let existing = videoInput {
            captureSession.removeInput(existing)
        }

        guard captureSession.canAddInput(newInput) else {
            throw CameraSessionError.configurationFailed
        }

        captureSession.addInput(newInput)

        // ✅ 디바이스 설정 적용
        applyPreferredConfiguration(to: device, matching: desiredZoomFactor)

        videoInput = newInput
        currentPosition = position

        // ✅ 녹화 중이므로 movieOutput 연결도 즉시 업데이트
        if let connection = movieOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = (position == .front)
            }
        }
    }

    private func startSessionIfNeeded() {
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }

    private func cameraDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        // ✅ 캐시 확인
        if let cached = deviceCache[position], cached.isConnected {
            return cached
        }

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInTrueDepthCamera, .builtInDualCamera, .builtInDualWideCamera],
            mediaType: .video,
            position: position
        )
        if let device = discovery.devices.first {
            deviceCache[position] = device
            return device
        }

        if let fallback = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) {
            deviceCache[position] = fallback
            return fallback
        }
        return nil
    }

    private var availablePositions: [AVCaptureDevice.Position] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInTrueDepthCamera, .builtInDualCamera, .builtInDualWideCamera],
            mediaType: .video,
            position: .unspecified
        )
        return discovery.devices.map { $0.position }.filter { $0 == .front || $0 == .back }.uniqued()
    }

    // ✅ 수정된 연결 미러링 업데이트
    private func updateConnectionMirroring() {
        // Photo output 연결 설정
        if let connection = photoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = (currentPosition == .front)
            }
        }

        // Movie output 연결 설정 (녹화 중일 수도 있음)
        if let connection = movieOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = (currentPosition == .front)
            }
        }
    }

    private func applyPreferredConfiguration(to device: AVCaptureDevice, matching previousZoom: CGFloat) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if device.isSmoothAutoFocusSupported {
                device.isSmoothAutoFocusEnabled = true
            }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }

            let minZoom = max(previousZoom, 1.0)
            let clamped = min(device.activeFormat.videoMaxZoomFactor, minZoom)
            device.videoZoomFactor = clamped
        } catch {
            // Ignore configuration errors; device will keep defaults
        }
    }

    private func startRecordingTimerIfNeeded(maxDurationMs: Int?) {
        recordingTimer?.cancel()
        recordingTimer = nil

        guard let maxDurationMs, maxDurationMs > 0 else { return }

        let timer = DispatchSource.makeTimerSource(queue: sessionQueue)
        timer.schedule(deadline: .now() + .milliseconds(maxDurationMs))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            if self.movieOutput.isRecording {
                self.isCancellingRecording = false
                self.movieOutput.stopRecording()
            }
        }
        recordingTimer = timer
        timer.resume()
    }

    private func temporaryURL(extension ext: String) -> URL {
        let fileName = UUID().uuidString + "." + ext
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
    }

    private func cleanupRecordingFile(_ url: URL?) {
        if let url {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: AVCapturePhotoCaptureDelegate
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let completion = photoCompletion
        photoCompletion = nil

        if let error {
            completion?(.failure(error))
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            completion?(.failure(CameraSessionError.configurationFailed))
            return
        }

        let url = temporaryURL(extension: "jpg")
        do {
            try data.write(to: url)
            completion?(.success(url.path))
        } catch {
            completion?(.failure(error))
        }
    }

    // MARK: AVCaptureFileOutputRecordingDelegate
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {}

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        recordingTimer?.cancel()
        recordingTimer = nil

        let completion = recordingCompletion
        recordingCompletion = nil

        if let error {
            completion?(.failure(error))
            delegate?.cameraSessionManager(self, didFailRecording: error)
            cleanupRecordingFile(outputFileURL)
            return
        }

        if isCancellingRecording {
            cleanupRecordingFile(outputFileURL)
            completion?(.success(""))
            isCancellingRecording = false
            return
        }

        completion?(.success(outputFileURL.path))
        delegate?.cameraSessionManager(self, didFinishRecording: outputFileURL.path)
    }
}

// MARK: - Preview bridge
fileprivate final class CameraPreviewFactory: NSObject, FlutterPlatformViewFactory {
    private let sessionManager: CameraSessionManager

    init(sessionManager: CameraSessionManager) {
        self.sessionManager = sessionManager
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        CameraPreviewView(frame: frame, sessionManager: sessionManager)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

fileprivate final class CameraPreviewView: NSObject, FlutterPlatformView {
    private let previewView = PreviewView()

    init(frame: CGRect, sessionManager: CameraSessionManager) {
        super.init()
        previewView.frame = frame
        previewView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sessionManager.registerPreviewLayer(previewView.previewLayer)
    }

    func view() -> UIView {
        previewView
    }
}

fileprivate final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
    }
}

fileprivate extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}