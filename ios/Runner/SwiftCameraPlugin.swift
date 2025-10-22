import Flutter
import UIKit
import AVFoundation

// MARK: - Flutter Plugin Entry Point
public final class SwiftCameraPlugin: NSObject, FlutterPlugin {
    private static let channelName = "com.soi.camera"

    private let sessionManager = CameraSessionManager()
    private var methodChannel: FlutterMethodChannel?

    private func resolve(_ result: @escaping FlutterResult, with value: Any) {
        DispatchQueue.main.async {
            result(value)
        }
    }

    private func reject(_ result: @escaping FlutterResult, code: String, message: String) {
        DispatchQueue.main.async {
            result(FlutterError(code: code, message: message, details: nil))
        }
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftCameraPlugin()
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        instance.methodChannel = channel
        instance.sessionManager.delegate = instance
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.register(
            CameraPreviewFactory(sessionManager: instance.sessionManager),
            withId: "com.soi.camera/preview"
        )
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initCamera":
            sessionManager.ensureSessionConfigured { [weak self] configurationResult in
                guard let self else { return }
                switch configurationResult {
                case .success:
                    self.resolve(result, with: true)
                case .failure(let error):
                    self.reject(result, code: "INIT_ERROR", message: error.localizedDescription)
                }
            }

        case "takePicture":
            sessionManager.capturePhoto { [weak self] captureResult in
                guard let self else { return }
                switch captureResult {
                case .success(let path):
                    self.resolve(result, with: path)
                case .failure(let error):
                    self.reject(result, code: "CAPTURE_ERROR", message: error.localizedDescription)
                }
            }

        case "switchCamera":
            sessionManager.switchCamera { [weak self] switchResult in
                guard let self else { return }
                switch switchResult {
                case .success:
                    self.resolve(result, with: "Camera switched")
                case .failure(let error):
                    self.reject(result, code: "SWITCH_ERROR", message: error.localizedDescription)
                }
            }

        case "setFlash":
            guard let args = call.arguments as? [String: Any],
                  let isOn = args["isOn"] as? Bool else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing isOn", details: nil))
                return
            }
            sessionManager.setFlash(enabled: isOn) { [weak self] flashResult in
                guard let self else { return }
                switch flashResult {
                case .success:
                    self.resolve(result, with: "Flash set")
                case .failure(let error):
                    self.reject(result, code: "FLASH_ERROR", message: error.localizedDescription)
                }
            }

        case "setZoom":
            guard let args = call.arguments as? [String: Any],
                  let zoomValue = args["zoomValue"] as? Double else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing zoomValue", details: nil))
                return
            }
            sessionManager.setZoom(to: zoomValue) { [weak self] zoomResult in
                guard let self else { return }
                switch zoomResult {
                case .success:
                    self.resolve(result, with: "Zoom set")
                case .failure(let error):
                    self.reject(result, code: "ZOOM_ERROR", message: error.localizedDescription)
                }
            }

        case "setBrightness":
            guard let args = call.arguments as? [String: Any],
                  let value = args["value"] as? Double else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing value", details: nil))
                return
            }
            sessionManager.setBrightness(value) { [weak self] brightnessResult in
                guard let self else { return }
                switch brightnessResult {
                case .success:
                    self.resolve(result, with: "Brightness set")
                case .failure(let error):
                    self.reject(result, code: "BRIGHTNESS_ERROR", message: error.localizedDescription)
                }
            }

        case "pauseCamera":
            sessionManager.pauseSession()
            result("Camera paused")

        case "resumeCamera":
            sessionManager.resumeSession()
            result("Camera resumed")

        case "disposeCamera":
            sessionManager.dispose()
            result("Camera disposed")

        case "optimizeCamera":
            sessionManager.optimizeForCapture { [weak self] optimizeResult in
                guard let self else { return }
                switch optimizeResult {
                case .success:
                    self.resolve(result, with: "Camera optimized")
                case .failure(let error):
                    self.reject(result, code: "OPTIMIZE_ERROR", message: error.localizedDescription)
                }
            }

        case "getAvailableZoomLevels":
            sessionManager.availableZoomLevels { [weak self] levels in
                guard let self else { return }
                self.resolve(result, with: levels)
            }

        case "startVideoRecording":
            let durationMs = (call.arguments as? [String: Any])?["maxDurationMs"] as? Int
            sessionManager.startRecording(maxDurationMs: durationMs) { [weak self] startResult in
                guard let self else { return }
                switch startResult {
                case .success:
                    self.resolve(result, with: true)
                case .failure(let error):
                    self.reject(result, code: "RECORDING_ERROR", message: error.localizedDescription)
                }
            }

        case "stopVideoRecording":
            sessionManager.stopRecording(cancel: false) { [weak self] stopResult in
                guard let self else { return }
                switch stopResult {
                case .success(let path):
                    self.resolve(result, with: path)
                case .failure(let error):
                    self.reject(result, code: "STOP_ERROR", message: error.localizedDescription)
                }
            }

        case "cancelVideoRecording":
            sessionManager.stopRecording(cancel: true) { [weak self] stopResult in
                guard let self else { return }
                switch stopResult {
                case .success:
                    self.resolve(result, with: "")
                case .failure(let error):
                    self.reject(result, code: "STOP_ERROR", message: error.localizedDescription)
                }
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

// MARK: - Session Delegate bridge
extension SwiftCameraPlugin: CameraSessionManagerDelegate {
    func cameraSessionManager(_ manager: CameraSessionManager, didFinishRecording path: String) {
        methodChannel?.invokeMethod("onVideoRecorded", arguments: ["path": path])
    }

    func cameraSessionManager(_ manager: CameraSessionManager, didFailRecording error: Error) {
        methodChannel?.invokeMethod("onVideoError", arguments: ["message": error.localizedDescription])
    }
}

// MARK: - Camera Session Manager
protocol CameraSessionManagerDelegate: AnyObject {
    func cameraSessionManager(_ manager: CameraSessionManager, didFinishRecording path: String)
    func cameraSessionManager(_ manager: CameraSessionManager, didFailRecording error: Error)
}

enum CameraSessionError: LocalizedError {
    case deviceUnavailable
    case configurationFailed
    case alreadyRecording
    case notRecording
    case writerSetupFailed(String)
    case switchNotSupportedWhileRecording

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
        case .writerSetupFailed(let reason):
            return reason
        case .switchNotSupportedWhileRecording:
            return "Switching cameras while recording isn't supported on this device"
        }
    }
}

final class CameraSessionManager: NSObject, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    // MARK: Session state
    weak var delegate: CameraSessionManagerDelegate?

    private let sessionQueue = DispatchQueue(label: "com.soi.camera.session")
    private let writerQueue = DispatchQueue(label: "com.soi.camera.writer")

    private let isMultiCamSupported = AVCaptureMultiCamSession.isMultiCamSupported
    private(set) var captureSession: AVCaptureSession

    private var isConfigured = false
    private var currentPosition: AVCaptureDevice.Position = .back
    private var activeCamera: AVCaptureDevice.Position = .back

    private var backDeviceInput: AVCaptureDeviceInput?
    private var frontDeviceInput: AVCaptureDeviceInput?
    private var currentDeviceInput: AVCaptureDeviceInput? { didSet { currentDevice = currentDeviceInput?.device } }
    private var currentDevice: AVCaptureDevice?

    private var photoOutput: AVCapturePhotoOutput?
    private var backVideoOutput: AVCaptureVideoDataOutput?
    private var frontVideoOutput: AVCaptureVideoDataOutput?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var audioInput: AVCaptureDeviceInput?

    private var previewLayers = NSHashTable<AVCaptureVideoPreviewLayer>.weakObjects()
    private var preferredFormatDimensions: NormalizedDimensions?
    private var preferredFrameRate: Double = 30.0
    private var hasDeterminedConstraints = false

    // Recording state
    private var isRecording = false
    private var assetWriter: AVAssetWriter?
    private var writerVideoInput: AVAssetWriterInput?
    private var writerAudioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var recordingURL: URL?
    private var recordingCompletion: ((Result<String, Error>) -> Void)?
    private var recordingTimer: DispatchSourceTimer?
    private var lastVideoPTS: CMTime?
    private var writerVideoDimensions: CMVideoDimensions?

    private var flashMode: AVCaptureDevice.FlashMode = .off
    private var photoCompletion: ((Result<String, Error>) -> Void)?

    override init() {
        if isMultiCamSupported,
           AVCaptureMultiCamSession.isMultiCamSupported {
            captureSession = AVCaptureMultiCamSession()
        } else {
            let session = AVCaptureSession()
            session.sessionPreset = .high
            captureSession = session
        }
        super.init()
    }

    // MARK: Public API
    func ensureSessionConfigured(completion: @escaping (Result<Void, Error>) -> Void) {
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
        ensureSessionConfigured { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                self.sessionQueue.async {
                    guard let photoOutput = self.photoOutput else {
                        completion(.failure(CameraSessionError.configurationFailed))
                        return
                    }

                    let settings = AVCapturePhotoSettings()
                    if photoOutput.supportedFlashModes.contains(self.flashMode) {
                        settings.flashMode = self.flashMode
                    } else if photoOutput.supportedFlashModes.contains(.off) {
                        settings.flashMode = .off
                    }

                    self.photoCompletion = completion
                    photoOutput.capturePhoto(with: settings, delegate: self)
                }
            }
        }
    }

    func switchCamera(completion: @escaping (Result<Void, Error>) -> Void) {
        ensureSessionConfigured { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                self.sessionQueue.async {
                    if self.isMultiCamSupported {
                        self.activeCamera = self.activeCamera == .back ? .front : .back
                        self.updatePreviewMirroring()
                        completion(.success(()))
                        return
                    }

                    if self.isRecording {
                        completion(.failure(CameraSessionError.switchNotSupportedWhileRecording))
                        return
                    }

                    guard let currentInput = self.currentDeviceInput else {
                        completion(.failure(CameraSessionError.configurationFailed))
                        return
                    }

                    let targetPosition: AVCaptureDevice.Position = (self.currentPosition == .back) ? .front : .back
                    guard let newDevice = self.cameraDevice(for: targetPosition) else {
                        completion(.failure(CameraSessionError.deviceUnavailable))
                        return
                    }

                    do {
                        try self.applyPreferredFormat(to: newDevice)
                        let newInput = try AVCaptureDeviceInput(device: newDevice)
                        let wasRunning = self.captureSession.isRunning
                        if wasRunning { self.captureSession.stopRunning() }

                        self.captureSession.beginConfiguration()
                        self.captureSession.removeInput(currentInput)
                        if self.captureSession.canAddInput(newInput) {
                            self.captureSession.addInput(newInput)
                            self.currentDeviceInput = newInput
                            self.currentPosition = targetPosition
                        } else {
                            self.captureSession.addInput(currentInput)
                            self.captureSession.commitConfiguration()
                            if wasRunning { self.captureSession.startRunning() }
                            completion(.failure(CameraSessionError.configurationFailed))
                            return
                        }
                        self.captureSession.commitConfiguration()

                        if wasRunning { self.captureSession.startRunning() }
                        self.updatePreviewMirroring()

                        if self.isRecording {
                            self.appendBridgeFrames(durationMs: 150)
                        }
                        completion(.success(()))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    func setFlash(enabled: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async {
            self.flashMode = enabled ? .on : .off
            completion(.success(()))
        }
    }

    func setZoom(to factor: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async {
            guard let device = self.currentDevice else {
                completion(.failure(CameraSessionError.deviceUnavailable))
                return
            }
            do {
                try device.lockForConfiguration()
                let maxFactor = min(device.activeFormat.videoMaxZoomFactor, CGFloat(max(factor, 1.0)))
                device.ramp(toVideoZoomFactor: maxFactor, withRate: 4.0)
                device.unlockForConfiguration()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func setBrightness(_ value: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async {
            guard let device = self.currentDevice else {
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
            var levels: Set<Double> = [1.0]
            if let device = self.device(for: .back) {
                if device.minAvailableVideoZoomFactor <= 0.5 && device.maxAvailableVideoZoomFactor >= 0.5 {
                    levels.insert(0.5)
                }
                if device.maxAvailableVideoZoomFactor >= 2.0 { levels.insert(2.0) }
                if device.maxAvailableVideoZoomFactor >= 3.0 { levels.insert(3.0) }
            }
            completion(levels.sorted())
        }
    }

    func startRecording(maxDurationMs: Int?, completion: @escaping (Result<Void, Error>) -> Void) {
        ensureSessionConfigured { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                self.sessionQueue.async {
                    guard !self.isRecording else {
                        completion(.failure(CameraSessionError.alreadyRecording))
                        return
                    }
                    do {
                        try self.prepareWriter()
                        self.isRecording = true
                        self.startRecordingTimerIfNeeded(maxDurationMs)
                        completion(.success(()))
                    } catch {
                        self.resetWriter()
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    func stopRecording(cancel: Bool, completion: @escaping (Result<String, Error>) -> Void) {
        sessionQueue.async {
            guard self.isRecording else {
                completion(.failure(CameraSessionError.notRecording))
                return
            }
            self.recordingCompletion = completion
            self.finishRecording(cancelled: cancel)
        }
    }

    func pauseSession() {
        sessionQueue.async {
            if self.captureSession.isRunning { self.captureSession.stopRunning() }
        }
    }

    func resumeSession() {
        ensureSessionConfigured { _ in }
    }

    func dispose() {
        sessionQueue.sync {
            if self.captureSession.isRunning { self.captureSession.stopRunning() }
            self.captureSession.inputs.forEach { self.captureSession.removeInput($0) }
            self.captureSession.outputs.forEach { self.captureSession.removeOutput($0) }
            self.resetWriter()
            self.isConfigured = false
            self.preferredFormatDimensions = nil
            self.preferredFrameRate = 30.0
            self.hasDeterminedConstraints = false
        }
    }

    func optimizeForCapture(completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async {
            guard let device = self.currentDevice else {
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

    func registerPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        previewLayers.add(layer)
        layer.session = captureSession
        layer.videoGravity = .resizeAspectFill
        DispatchQueue.main.async {
            layer.connection?.videoOrientation = .portrait
        }
        ensureSessionConfigured { _ in }
    }

    // MARK: Private helpers
    private func configureSession() throws {
        determineCaptureConstraints()
        captureSession.beginConfiguration()

        if isMultiCamSupported {
            try configureMultiCamSession()
        } else {
            try configureSingleCamSession()
        }

        try configurePhotoOutput()
        try configureAudioIfNeeded()

        captureSession.commitConfiguration()
        updatePreviewMirroring()
    }

    private func configureSingleCamSession() throws {
        let initialPosition: AVCaptureDevice.Position = .back
        guard let device = cameraDevice(for: initialPosition) else { throw CameraSessionError.deviceUnavailable }
        try applyPreferredFormat(to: device)
        let input = try AVCaptureDeviceInput(device: device)
        guard captureSession.canAddInput(input) else { throw CameraSessionError.configurationFailed }
        captureSession.addInput(input)
        currentDeviceInput = input
        currentDevice = device
        currentPosition = initialPosition

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = false
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.soi.camera.video"))
        guard captureSession.canAddOutput(videoOutput) else { throw CameraSessionError.configurationFailed }
        captureSession.addOutput(videoOutput)
        backVideoOutput = videoOutput
    }

    private func configureMultiCamSession() throws {
        guard let multiSession = captureSession as? AVCaptureMultiCamSession else {
            throw CameraSessionError.configurationFailed
        }

        guard let backDevice = cameraDevice(for: .back) else { throw CameraSessionError.deviceUnavailable }
        try applyPreferredFormat(to: backDevice)
        let backInput = try AVCaptureDeviceInput(device: backDevice)
        if multiSession.canAddInput(backInput) { multiSession.addInput(backInput) }
        backDeviceInput = backInput
        currentDeviceInput = backInput
        currentDevice = backDevice
        currentPosition = .back
        activeCamera = .back

        guard let frontDevice = cameraDevice(for: .front) else { throw CameraSessionError.deviceUnavailable }
        try applyPreferredFormat(to: frontDevice)
        let frontInput = try AVCaptureDeviceInput(device: frontDevice)
        if multiSession.canAddInput(frontInput) { multiSession.addInput(frontInput) }
        frontDeviceInput = frontInput

        let backOutput = AVCaptureVideoDataOutput()
        backOutput.alwaysDiscardsLateVideoFrames = false
        backOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.soi.camera.video.back"))
        if multiSession.canAddOutput(backOutput) { multiSession.addOutput(backOutput) }
        backVideoOutput = backOutput

        let frontOutput = AVCaptureVideoDataOutput()
        frontOutput.alwaysDiscardsLateVideoFrames = false
        frontOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.soi.camera.video.front"))
        if multiSession.canAddOutput(frontOutput) { multiSession.addOutput(frontOutput) }
        frontVideoOutput = frontOutput
    }

    private func configurePhotoOutput() throws {
        let output = AVCapturePhotoOutput()
        guard captureSession.canAddOutput(output) else { throw CameraSessionError.configurationFailed }
        captureSession.addOutput(output)
        photoOutput = output
    }

    private func configureAudioIfNeeded() throws {
        if audioInput != nil { return }
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else { return }
        let input = try AVCaptureDeviceInput(device: audioDevice)
        if captureSession.canAddInput(input) { captureSession.addInput(input); audioInput = input }

        let audioDataOutput = AVCaptureAudioDataOutput()
        audioDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.soi.camera.audio"))
        if captureSession.canAddOutput(audioDataOutput) { captureSession.addOutput(audioDataOutput) }
        audioOutput = audioDataOutput
    }

    private func startSessionIfNeeded() {
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }

    private func updatePreviewMirroring() {
        let isFront = (isMultiCamSupported && activeCamera == .front) || (!isMultiCamSupported && currentPosition == .front)

        for layer in previewLayers.allObjects {
            guard let connection = layer.connection else { continue }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = isFront
            }
        }

        for output in captureSession.outputs {
            for connection in output.connections where connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }
    }

    private func cameraDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType]
        if #available(iOS 13.0, *) {
            switch position {
            case .front:
                deviceTypes = [.builtInTrueDepthCamera, .builtInWideAngleCamera, .builtInUltraWideCamera]
            case .back:
                deviceTypes = [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera]
            default:
                deviceTypes = [.builtInWideAngleCamera]
            }
        } else {
            deviceTypes = [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInDualCamera]
        }

        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: position)
        if let device = discovery.devices.first { return device }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }

    private func device(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if currentDevice?.position == position { return currentDevice }
        return cameraDevice(for: position)
    }

    private func applyPreferredFormat(to device: AVCaptureDevice) throws {
        if !hasDeterminedConstraints {
            determineCaptureConstraints()
        }

        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        let format: AVCaptureDevice.Format
        var targetFrameRate = preferredFrameRate

        if let dims = preferredFormatDimensions,
           let match = bestFormat(for: device, matching: dims, minimumFrameRate: preferredFrameRate) {
            format = match.format
            targetFrameRate = match.frameRate
        } else if preferredFormatDimensions == nil {
            let fallback = chooseBestFormat(for: device)
            format = fallback.format
            targetFrameRate = fallback.frameRate
            preferredFormatDimensions = normalizeDimensions(CMVideoFormatDescriptionGetDimensions(format.formatDescription))
            hasDeterminedConstraints = true
        } else {
            // Recompute constraints once more in case formats have changed (e.g., front camera fallback)
            let previousDims = preferredFormatDimensions
            preferredFormatDimensions = nil
            hasDeterminedConstraints = false
            determineCaptureConstraints()

            if let dims = preferredFormatDimensions,
               let retry = bestFormat(for: device, matching: dims, minimumFrameRate: preferredFrameRate) {
                format = retry.format
                targetFrameRate = retry.frameRate
            } else {
                preferredFormatDimensions = previousDims
                hasDeterminedConstraints = true
                throw CameraSessionError.configurationFailed
            }
        }

        device.activeFormat = format
        setDevice(device, toFrameRate: targetFrameRate, using: format)
    }

    private func bestFormat(
        for device: AVCaptureDevice,
        matching dims: NormalizedDimensions,
        minimumFrameRate: Double
    ) -> (format: AVCaptureDevice.Format, frameRate: Double)? {
        let candidates = device.formats
            .filter { normalizeDimensions(CMVideoFormatDescriptionGetDimensions($0.formatDescription)) == dims }
            .sorted { maximumFrameRate(for: $0) > maximumFrameRate(for: $1) }

        for format in candidates {
            let maxRate = maximumFrameRate(for: format)
            if maxRate < 15 { continue }
            let targetRate = min(maxRate, min(60.0, minimumFrameRate))
            if targetRate >= 15 {
                return (format, targetRate)
            }
        }
        return nil
    }

    private func chooseBestFormat(for device: AVCaptureDevice) -> (format: AVCaptureDevice.Format, frameRate: Double) {
        var bestFormat = device.activeFormat
        var bestRate = maximumFrameRate(for: bestFormat)
        var bestArea = area(of: normalizeDimensions(CMVideoFormatDescriptionGetDimensions(bestFormat.formatDescription)))

        for format in device.formats {
            let dims = normalizeDimensions(CMVideoFormatDescriptionGetDimensions(format.formatDescription))
            let maxRate = maximumFrameRate(for: format)
            if maxRate < 15 { continue }
            let formatArea = area(of: dims)
            if formatArea > bestArea || (formatArea == bestArea && maxRate > bestRate) {
                bestFormat = format
                bestRate = maxRate
                bestArea = formatArea
            }
        }

        let targetRate = min(bestRate, 60.0)
        return (bestFormat, targetRate)
    }

    private func maximumFrameRate(for format: AVCaptureDevice.Format) -> Double {
        return format.videoSupportedFrameRateRanges.map { $0.maxFrameRate }.max() ?? 0.0
    }

    private func setDevice(_ device: AVCaptureDevice, toFrameRate frameRate: Double, using format: AVCaptureDevice.Format) {
        let ranges = format.videoSupportedFrameRateRanges
        guard let range = ranges
            .sorted(by: { $0.maxFrameRate > $1.maxFrameRate })
            .first(where: { $0.minFrameRate <= frameRate && frameRate <= $0.maxFrameRate }) ?? ranges.first else {
            return
        }

        let clamped = max(range.minFrameRate, min(range.maxFrameRate, frameRate))
        preferredFrameRate = clamped
        let duration = CMTimeMakeWithSeconds(1.0 / clamped, preferredTimescale: 600)
        device.activeVideoMinFrameDuration = duration
        device.activeVideoMaxFrameDuration = duration
    }

    private func determineCaptureConstraints() {
        guard !hasDeterminedConstraints else { return }

        let backDevice = rawVideoDevice(for: .back)
        let frontDevice = rawVideoDevice(for: .front)

        var selectedDims: NormalizedDimensions?
        var selectedRate: Double = preferredFrameRate

        if let back = backDevice {
            let backFormats = formatsMap(for: back)

            if let front = frontDevice {
                let frontFormats = formatsMap(for: front)
                let commonDims = Array(Set(backFormats.keys).intersection(Set(frontFormats.keys)))
                    .sorted { area(of: $0) > area(of: $1) }

                let ratePreferences: [Double] = [60.0, 30.0, 24.0, 15.0]
                for dims in commonDims {
                    guard let backRate = backFormats[dims], let frontRate = frontFormats[dims] else { continue }
                    let minRate = min(backRate, frontRate)
                    guard minRate >= 15 else { continue }
                    let chosenRate: Double
                    if minRate >= 29.0 {
                        chosenRate = 30.0
                    } else {
                        chosenRate = ratePreferences.first(where: { $0 <= minRate }) ?? minRate
                    }
                    selectedDims = dims
                    selectedRate = chosenRate
                    break
                }

                if selectedDims == nil, let fallbackDims = commonDims.first,
                   let backRate = backFormats[fallbackDims], let frontRate = frontFormats[fallbackDims] {
                    selectedDims = fallbackDims
                    let minRate = min(backRate, frontRate)
                    if minRate >= 29.0 {
                        selectedRate = 30.0
                    } else {
                        selectedRate = minRate
                    }
                }
            } else {
                let orderedDims = Array(backFormats.keys)
                    .sorted { area(of: $0) > area(of: $1) }
                if let dims = orderedDims.first, let rate = backFormats[dims] {
                    selectedDims = dims
                    selectedRate = rate >= 29.0 ? 30.0 : rate
                }
            }
        }

        if selectedDims == nil {
            selectedDims = normalizeDimensions(CMVideoDimensions(width: 1280, height: 720))
            selectedRate = 30.0
        }

        preferredFormatDimensions = selectedDims
        preferredFrameRate = min(selectedRate, 30.0)
        preferredFrameRate = max(preferredFrameRate, 15.0)
        hasDeterminedConstraints = true
    }

    private func formatsMap(for device: AVCaptureDevice) -> [NormalizedDimensions: Double] {
        var map: [NormalizedDimensions: Double] = [:]
        for format in device.formats {
            let dims = normalizeDimensions(CMVideoFormatDescriptionGetDimensions(format.formatDescription))
            let maxRate = maximumFrameRate(for: format)
            if maxRate < 15 { continue }
            if let existing = map[dims], existing >= maxRate { continue }
            map[dims] = maxRate
        }
        return map
    }

    private func rawVideoDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType]
        if #available(iOS 13.0, *) {
            switch position {
            case .front:
                deviceTypes = [.builtInTrueDepthCamera, .builtInWideAngleCamera, .builtInUltraWideCamera]
            case .back:
                deviceTypes = [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera]
            default:
                deviceTypes = [.builtInWideAngleCamera]
            }
        } else {
            deviceTypes = [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInDualCamera]
        }

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: position
        )

        if let device = discovery.devices.first { return device }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }

    // MARK: Photo delegate
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            photoCompletion?(.failure(error))
            photoCompletion = nil
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            photoCompletion?(.failure(CameraSessionError.configurationFailed))
            photoCompletion = nil
            return
        }

        let fileURL = temporaryFileURL(extension: "jpg")
        do {
            try data.write(to: fileURL)
            photoCompletion?(.success(fileURL.path))
        } catch {
            photoCompletion?(.failure(error))
        }
        photoCompletion = nil
    }

    // MARK: Recording helpers
    private func prepareWriter() throws {
        let outputURL = temporaryFileURL(extension: "mov")
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

        guard let videoOutput = isMultiCamSupported ? (activeCamera == .front ? frontVideoOutput : backVideoOutput) : backVideoOutput else {
            throw CameraSessionError.writerSetupFailed("Missing video output")
        }

        let videoSettings = videoOutput.recommendedVideoSettingsForAssetWriter(writingTo: .mov) as? [String: Any] ?? [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1080,
            AVVideoHeightKey: 1920
        ]

        if let widthNumber = videoSettings[AVVideoWidthKey] as? NSNumber,
           let heightNumber = videoSettings[AVVideoHeightKey] as? NSNumber {
            writerVideoDimensions = CMVideoDimensions(width: Int32(widthNumber.intValue), height: Int32(heightNumber.intValue))
        } else if let widthInt = videoSettings[AVVideoWidthKey] as? Int,
                  let heightInt = videoSettings[AVVideoHeightKey] as? Int {
            writerVideoDimensions = CMVideoDimensions(width: Int32(widthInt), height: Int32(heightInt))
        } else if let widthDouble = videoSettings[AVVideoWidthKey] as? Double,
                  let heightDouble = videoSettings[AVVideoHeightKey] as? Double {
            writerVideoDimensions = CMVideoDimensions(width: Int32(widthDouble.rounded()), height: Int32(heightDouble.rounded()))
        } else if let activeFormat = currentDevice?.activeFormat {
            writerVideoDimensions = CMVideoFormatDescriptionGetDimensions(activeFormat.formatDescription)
        } else {
            writerVideoDimensions = nil
        }

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true

        if writer.canAdd(videoInput) {
            writer.add(videoInput)
        } else {
            throw CameraSessionError.writerSetupFailed("Cannot add video input")
        }

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])

        guard let audioOutput = audioOutput else {
            throw CameraSessionError.writerSetupFailed("Missing audio output")
        }

        let audioSettings = audioOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mov) as? [String: Any] ?? [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey: 128000
        ]

        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput.expectsMediaDataInRealTime = true
        if writer.canAdd(audioInput) {
            writer.add(audioInput)
        }

        assetWriter = writer
        writerVideoInput = videoInput
        writerAudioInput = audioInput
        pixelBufferAdaptor = adaptor
        recordingURL = outputURL
        lastVideoPTS = nil
    }

    private func startRecordingTimerIfNeeded(_ maxDurationMs: Int?) {
        recordingTimer?.cancel()
        recordingTimer = nil

        guard let maxDurationMs, maxDurationMs > 0 else { return }

        let timer = DispatchSource.makeTimerSource(queue: sessionQueue)
        timer.schedule(deadline: .now() + .milliseconds(maxDurationMs))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.finishRecording(cancelled: false)
        }
        recordingTimer = timer
        timer.resume()
    }

    private func finishRecording(cancelled: Bool) {
        recordingTimer?.cancel()
        recordingTimer = nil
        let writer = assetWriter
        let completion = recordingCompletion
        recordingCompletion = nil
        isRecording = false

        guard let writer else {
            completion?(.failure(CameraSessionError.writerSetupFailed("Writer missing")))
            return
        }

        writerQueue.async { [weak self] in
            guard let self else { return }

            if cancelled {
                writer.cancelWriting()
                if let url = self.recordingURL {
                    try? FileManager.default.removeItem(at: url)
                }
                DispatchQueue.main.async {
                    completion?(.success("") )
                }
                self.resetWriter()
                return
            }

            if writer.status == .unknown {
                writer.cancelWriting()
                let error = CameraSessionError.writerSetupFailed("Recording stopped before frames were captured")
                if let url = self.recordingURL {
                    try? FileManager.default.removeItem(at: url)
                }
                DispatchQueue.main.async {
                    completion?(.success(""))
                }
                self.resetWriter()
                return
            }

            if writer.status == .failed {
                let error = writer.error ?? CameraSessionError.writerSetupFailed("Writer failed")
                DispatchQueue.main.async {
                    completion?(.failure(error))
                    self.delegate?.cameraSessionManager(self, didFailRecording: error)
                }
                self.resetWriter()
                return
            }

            self.writerVideoInput?.markAsFinished()
            self.writerAudioInput?.markAsFinished()
            writer.finishWriting {
                DispatchQueue.main.async {
                    if writer.status == .completed, let path = self.recordingURL?.path {
                        completion?(.success(path))
                        self.delegate?.cameraSessionManager(self, didFinishRecording: path)
                    } else {
                        let error = writer.error ?? CameraSessionError.writerSetupFailed("Unknown writer error")
                        completion?(.failure(error))
                        self.delegate?.cameraSessionManager(self, didFailRecording: error)
                    }
                }
                self.resetWriter()
            }
        }
    }

    private func resetWriter() {
        assetWriter = nil
        writerVideoInput = nil
        writerAudioInput = nil
        pixelBufferAdaptor = nil
        recordingURL = nil
        lastVideoPTS = nil
        writerVideoDimensions = nil
    }

    private func appendBridgeFrames(durationMs: Int) {
        guard !isMultiCamSupported,
              isRecording,
              let adaptor = pixelBufferAdaptor,
              let videoInput = writerVideoInput,
              let lastPTS = lastVideoPTS,
              let dims = writerVideoDimensions,
              dims.width > 0,
              dims.height > 0 else { return }

        let fps: Int32 = Int32(preferredFrameRate.rounded()) > 0 ? Int32(preferredFrameRate.rounded()) : 30
        let frameDuration = CMTime(value: 1, timescale: fps)
        let frameCount = max(1, (durationMs * Int(fps)) / 1000)

        writerQueue.async {
            for frameIndex in 1...frameCount {
                autoreleasepool {
                    var pixelBuffer: CVPixelBuffer?
                    CVPixelBufferCreate(kCFAllocatorDefault,
                                        Int(dims.width),
                                        Int(dims.height),
                                        kCVPixelFormatType_32BGRA,
                                        nil,
                                        &pixelBuffer)
                    guard let buffer = pixelBuffer else { return }
                    CVPixelBufferLockBaseAddress(buffer, [])
                    if let base = CVPixelBufferGetBaseAddress(buffer) {
                        memset(base, 0, CVPixelBufferGetDataSize(buffer))
                    }
                    CVPixelBufferUnlockBaseAddress(buffer, [])

                    let pts = CMTimeAdd(lastPTS, CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex)))
                    while !videoInput.isReadyForMoreMediaData {
                        usleep(1_000)
                    }
                    adaptor.append(buffer, withPresentationTime: pts)
                    self.lastVideoPTS = pts
                }
            }
        }
    }

    private func temporaryFileURL(extension ext: String) -> URL {
        let filename = UUID().uuidString + "." + ext
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
    }

    // MARK: Sample buffer delegates
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRecording,
              let writer = assetWriter,
              writer.status != .failed,
              let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }

        let mediaType = CMFormatDescriptionGetMediaType(formatDescription)

        if mediaType == kCMMediaType_Video {
            if isMultiCamSupported {
                let isFrontBuffer = (output === frontVideoOutput)
                if (activeCamera == .front && !isFrontBuffer) || (activeCamera == .back && isFrontBuffer) {
                    return
                }
            }
            writerQueue.async {
                guard let writer = self.assetWriter,
                      let videoInput = self.writerVideoInput else { return }

                if writer.status == .failed { return }

                if writer.status == .unknown {
                    let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    writer.startWriting()
                    writer.startSession(atSourceTime: timestamp)
                    self.lastVideoPTS = timestamp
                }

                if writer.status == .writing {
                    while !videoInput.isReadyForMoreMediaData {
                        usleep(1_000)
                    }
                    if videoInput.append(sampleBuffer) {
                        self.lastVideoPTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    }
                }
            }
        } else if mediaType == kCMMediaType_Audio {
            writerQueue.async {
                guard let writer = self.assetWriter,
                      let audioInput = self.writerAudioInput else { return }

                if writer.status != .writing { return }

                while !audioInput.isReadyForMoreMediaData {
                    usleep(1_000)
                }
                audioInput.append(sampleBuffer)
            }
        }
    }
}

// MARK: - Preview bridge
private final class CameraPreviewFactory: NSObject, FlutterPlatformViewFactory {
    private let sessionManager: CameraSessionManager

    init(sessionManager: CameraSessionManager) {
        self.sessionManager = sessionManager
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return CameraPreviewView(frame: frame, sessionManager: sessionManager)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

private final class PreviewView: UIView {
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

private final class CameraPreviewView: NSObject, FlutterPlatformView {
    private let previewView: PreviewView

    init(frame: CGRect, sessionManager: CameraSessionManager) {
        previewView = PreviewView(frame: frame)
        super.init()
        sessionManager.registerPreviewLayer(previewView.previewLayer)
        previewView.frame = frame
        previewView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    func view() -> UIView {
        previewView
    }
}

private extension AVCaptureDevice.Format {
    func supportsFrameRate(_ frameRate: Double) -> Bool {
        for range in videoSupportedFrameRateRanges {
            if range.minFrameRate <= frameRate && frameRate <= range.maxFrameRate {
                return true
            }
        }
        return false
    }
}

private struct NormalizedDimensions: Hashable {
    let width: Int32
    let height: Int32
}

private func normalizeDimensions(_ dims: CMVideoDimensions) -> NormalizedDimensions {
    let absWidth = abs(dims.width)
    let absHeight = abs(dims.height)
    let maxSide = max(absWidth, absHeight)
    let minSide = min(absWidth, absHeight)
    return NormalizedDimensions(width: maxSide, height: minSide)
}

private func area(of dims: NormalizedDimensions) -> Int64 {
    return Int64(dims.width) * Int64(dims.height)
}
