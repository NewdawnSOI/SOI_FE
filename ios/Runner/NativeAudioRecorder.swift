//
//  NativeAudioRecorder.swift
//  Runner
//
//  Created by [Your Name] on [Date].
//  Copyright © 2025 The Flutter Authors. All rights reserved.
//

import UIKit
import Flutter
import AVFoundation

// MARK: - NativeAudioRecorder
/// Flutter에서 MethodChannel을 통해 네이티브 오디오 녹음 기능을 제어하는 클래스입니다.
/// AVAudioRecorderDelegate를 채택하여 녹음 중 발생하는 이벤트를 처리합니다.
class NativeAudioRecorder: NSObject, AVAudioRecorderDelegate {
    
    // MARK: - Properties
    
    /// 실제 오디오 녹음을 담당하는 AVAudioRecorder 인스턴스입니다.
    private var audioRecorder: AVAudioRecorder?
    
    /// 녹음 시작 시간을 추적하기 위한 변수입니다.
    private var recordingStartTime: Date?
    
    /// 오디오 세션을 관리하기 위한 인스턴스입니다.
    private var recordingSession: AVAudioSession?
    
    // MARK: - Public Methods (Called from Flutter)
    
    /// Flutter로부터 받은 파일 경로를 사용하여 오디오 녹음을 시작합니다.
    /// - Parameters:
    ///   - filePath: 오디오 파일을 저장할 경로입니다. Flutter에서 생성하여 전달됩니다.
    ///   - result: 녹음 성공 시 파일 경로(String), 실패 시 FlutterError를 전달하는 콜백입니다.
    func startRecording(filePath: String, result: @escaping FlutterResult) {
        print("🎤 [Native] 녹음 시작 요청 - 파일 경로: \(filePath)")
        
        // 1. 오디오 세션 설정 및 활성화
        guard setupAudioSession(result: result) else { return }
        
        // 2. 녹음할 파일 경로 준비
        let audioURL = URL(fileURLWithPath: filePath)
        guard prepareDirectory(for: audioURL, result: result) else { return }
        
        // 3. AVAudioRecorder 생성 및 준비
        guard let recorder = createAndPrepareRecorder(url: audioURL, result: result) else { return }
        self.audioRecorder = recorder
        
        // 4. 녹음 시작
        if recorder.record() {
            recordingStartTime = Date()
            print("✅ [Native] 녹음 시작 성공! 파일: \(filePath)")
            result(filePath) // 성공 시, 파일 경로를 다시 Flutter로 전달
        } else {
            print("❌ [Native] 녹음 시작 실패")
            result(FlutterError(code: "RECORDING_ERROR", message: "Failed to start recording", details: nil))
        }
    }
    
    /// 현재 진행 중인 녹음을 중지합니다.
    /// - Parameter result: 중지된 파일의 경로(String?)를 Flutter로 전달하는 콜백입니다.
    func stopRecording(result: @escaping FlutterResult) {
        print("🎤 [Native] 녹음 중지 요청")

        // 녹음 중이 아니면 즉시 반환
        guard let recorder = audioRecorder, recorder.isRecording else {
            print("⚠️ [Native] 녹음 중이 아님 - 이미 중지됨")
            let filePath = audioRecorder?.url.path
            audioRecorder = nil
            recordingStartTime = nil
            result(filePath)
            return
        }

        // 파일 경로를 미리 저장
        let filePath = recorder.url.path

        // 녹음기를 중지합니다.
        recorder.stop()
        print("🎤 [Native] AVAudioRecorder.stop() 호출됨")

        // 리소스를 정리합니다.
        audioRecorder = nil
        recordingStartTime = nil

        // ✅ 동기적 대기 - 파일 finalization 시간 확보
        // AVAudioRecorder가 파일을 완전히 기록하고 닫을 시간을 줍니다
        Thread.sleep(forTimeInterval: 0.15)  // 150ms

        // ✅ 오디오 세션 비활성화 (result 반환 전에 완료)
        do {
            // notifyOthersOnDeactivation 옵션으로 다른 앱에 알림
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("✅ [Native] 오디오 세션 비활성화 성공")
        } catch {
            // 오디오 세션 비활성화 실패는 치명적이지 않으므로 경고만 출력
            print("⚠️ [Native] 오디오 세션 비활성화 실패 (무시 가능): \(error.localizedDescription)")
        }

        // ✅ 모든 작업 완료 후 Flutter로 콜백 반환
        print("✅ [Native] 녹음 중지 완료. 파일: \(filePath)")
        result(filePath)
    }
    
    /// 현재 녹음 중인지 여부를 확인합니다.
    /// - Parameter result: 녹음 중 여부(Bool)를 Flutter로 전달하는 콜백입니다.
    func isRecording(result: @escaping FlutterResult) {
        let isCurrentlyRecording = audioRecorder?.isRecording ?? false
        print("ℹ️ [Native] 녹음 상태 확인: \(isCurrentlyRecording)")
        result(isCurrentlyRecording)
    }
    
    /// 마이크 권한 상태 확인
    /// - Parameter result: 권한 상태(Bool)를 반환하는 Flutter 콜백
    func checkMicrophonePermission(result: @escaping FlutterResult) {
        let permission = AVAudioSession.sharedInstance().recordPermission
        let hasPermission = permission == .granted
        
        print("🔍 [Native iOS] 마이크 권한 상태: \(permission), hasPermission: \(hasPermission)")
        result(hasPermission)
    }
    
    /// 마이크 권한 요청
    /// - Parameter result: 권한 요청 결과(Bool)를 반환하는 Flutter 콜백
    func requestMicrophonePermission(result: @escaping FlutterResult) {
        print("🎤 [Native iOS] 마이크 권한 요청 시작")
        
        let session = AVAudioSession.sharedInstance()
        session.requestRecordPermission { granted in
            DispatchQueue.main.async {
                print("🎤 [Native iOS] 마이크 권한 요청 결과: \(granted)")
                result(granted)
            }
        }
    }

    /// prepareRecorder는 앱 시작 직후 녹음기를 선초기화해
    /// 첫 녹음 시작 전에 오디오 세션과 AVAudioRecorder 준비 비용을 앞당깁니다.
    func prepareRecorder(result: @escaping FlutterResult) {
        let warmupURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("audio_recorder_warmup.m4a")

        do {
            try configureAudioSession()
            try prepareDirectoryIfNeeded(for: warmupURL)

            let recorder = try buildPreparedRecorder(url: warmupURL)
            recorder.deleteRecording()
            audioRecorder = nil

            print("✅ [Native] 녹음기 선초기화 완료")
            result(true)
        } catch {
            print("❌ [Native] 녹음기 선초기화 실패: \(error.localizedDescription)")
            result(
                FlutterError(
                    code: "PREPARE_RECORDER_ERROR",
                    message: "Failed to prepare recorder",
                    details: error.localizedDescription
                )
            )
        }
    }

    // MARK: - Private Helper Methods

    /// configureAudioSession은 녹음에 필요한 AVAudioSession 카테고리와 활성 상태를 설정합니다.
    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()

        if audioSession.isOtherAudioPlaying {
            print("ℹ️ [Native] 다른 오디오가 재생 중 - 세션 설정 진행")
        }

        try audioSession.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .mixWithOthers]
        )
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        print("✅ [Native] 오디오 세션 활성화 성공")
    }
    
    /// 오디오 세션을 설정하고 활성화합니다.
    /// - Parameter result: 실패 시 FlutterError를 전달하기 위한 콜백입니다.
    /// - Returns: 성공 시 true, 실패 시 false를 반환합니다.
    private func setupAudioSession(result: @escaping FlutterResult) -> Bool {
        do {
            try configureAudioSession()
            return true
        } catch {
            print("❌ [Native] 오디오 세션 설정 실패: \(error.localizedDescription)")
            result(FlutterError(code: "SESSION_ERROR", message: "Audio session setup failed", details: error.localizedDescription))
            return false
        }
    }

    /// prepareDirectoryIfNeeded는 녹음용 임시 파일 디렉토리가 존재하도록 보장합니다.
    private func prepareDirectoryIfNeeded(for url: URL) throws {
        let parentDirectory = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDirectory.path) {
            try FileManager.default.createDirectory(
                at: parentDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
    
    /// 녹음 파일을 저장할 디렉토리가 존재하는지 확인하고, 없으면 생성합니다.
    /// - Parameters:
    ///   - url: 파일이 저장될 전체 URL입니다.
    ///   - result: 실패 시 FlutterError를 전달하기 위한 콜백입니다.
    /// - Returns: 성공 시 true, 실패 시 false를 반환합니다.
    private func prepareDirectory(for url: URL, result: @escaping FlutterResult) -> Bool {
        let parentDirectory = url.deletingLastPathComponent()
        print("📁 [Native] 파일 저장 디렉토리: \(parentDirectory.path)")
        
        do {
            try prepareDirectoryIfNeeded(for: url)
            print("✅ [Native] 디렉토리 생성 성공")
            return true
        } catch {
            print("❌ [Native] 디렉토리 생성 실패: \(error.localizedDescription)")
            result(FlutterError(code: "DIRECTORY_ERROR", message: "Failed to create directory", details: error.localizedDescription))
            return false
        }
    }

    /// buildPreparedRecorder는 공통 녹음 설정으로 AVAudioRecorder를 생성하고 prepareToRecord까지 완료합니다.
    private func buildPreparedRecorder(url: URL) throws -> AVAudioRecorder {
        let recorder = try AVAudioRecorder(url: url, settings: recorderSettings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true

        guard recorder.prepareToRecord() else {
            throw NSError(
                domain: "NativeAudioRecorder",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "Failed to prepare recording"]
            )
        }

        return recorder
    }

    private var recorderSettings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 22050,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64000,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
    }
    
    /// 오디오 설정을 정의하고, AVAudioRecorder 인스턴스를 생성 및 준비합니다.
    /// - Parameters:
    ///   - url: 녹음할 파일의 URL입니다.
    ///   - result: 실패 시 FlutterError를 전달하기 위한 콜백입니다.
    /// - Returns: 성공 시 준비된 AVAudioRecorder 인스턴스, 실패 시 nil을 반환합니다.
    private func createAndPrepareRecorder(url: URL, result: @escaping FlutterResult) -> AVAudioRecorder? {
        print("🎛️ [Native] 오디오 설정: \(recorderSettings)")

        do {
            let recorder = try buildPreparedRecorder(url: url)
            print("✅ [Native] AVAudioRecorder 준비 성공")
            return recorder
        } catch {
            print("❌ [Native] AVAudioRecorder 생성 실패: \(error.localizedDescription)")
            result(FlutterError(code: "RECORDING_ERROR", message: "Failed to create recorder", details: error.localizedDescription))
            return nil
        }
    }
    
    // MARK: - AVAudioRecorderDelegate
    
    /// 녹음이 완료되었을 때 호출되는 델리게이트 메서드입니다.
    /// - Parameters:
    ///   - recorder: 녹음을 완료한 AVAudioRecorder 인스턴스입니다.
    ///   - flag: 녹음이 성공적으로 완료되었는지 여부입니다.
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            print("✅ [Native] 델리게이트: 녹음이 성공적으로 완료되었습니다.")
        } else {
            print("❌ [Native] 델리게이트: 녹음 중 오류가 발생하여 중단되었습니다.")
        }
    }
}
