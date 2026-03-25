import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

typedef _PermissionStatusLoader = Future<PermissionStatus> Function();
typedef _PrimeRecorderResources = Future<void> Function();

/// API 기반 음성 댓글 오디오 컨트롤러
///
/// 음성 댓글의 재생/일시정지를 관리합니다.
/// Firebase 버전과 독립적으로 동작합니다.
///
/// 녹음 기능 추가:
/// - photo_editor_screen과의 호환성을 위해 녹음 관련 상태 관리 추가
/// - 실제 녹음은 audio_recorder_widget에서 처리
class AudioController extends ChangeNotifier {
  static const MethodChannel _recorderChannel = MethodChannel(
    'native_recorder',
  );

  AudioController({
    Future<PermissionStatus> Function()? loadMicrophonePermissionStatus,
    Future<void> Function()? primeRecorderResources,
  }) : _loadMicrophonePermissionStatus =
           loadMicrophonePermissionStatus ??
           _defaultLoadMicrophonePermissionStatus,
       _primeRecorderResources =
           primeRecorderResources ?? _defaultPrimeRecorderResources;

  static Future<PermissionStatus> _defaultLoadMicrophonePermissionStatus() {
    return Permission.microphone.status;
  }

  static Future<void> _defaultPrimeRecorderResources() async {
    await _recorderChannel.invokeMethod('prepareRecorder');
  }

  final _PermissionStatusLoader _loadMicrophonePermissionStatus;
  final _PrimeRecorderResources _primeRecorderResources;

  // ==================== 상태 관리 ====================

  /// AudioPlayer 인스턴스
  ap.AudioPlayer? _audioPlayer;

  /// 현재 재생 중인 오디오 URL
  String? _currentAudioUrl;

  /// 재생 상태
  bool _isPlaying = false;

  /// 로딩 상태
  bool _isLoading = false;

  /// 현재 재생 위치
  Duration _currentPosition = Duration.zero;

  /// 총 재생 시간
  Duration _totalDuration = Duration.zero;

  /// 에러 메시지
  String? _error;

  /// 스트림 구독
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<ap.PlayerState>? _stateSubscription;

  // ==================== 녹음 관련 상태 (photo_editor_screen 호환성) ====================

  /// 현재 녹음된 파일 경로
  String? _currentRecordingPath;

  /// 녹음 시간 (초)
  int _recordingDuration = 0;

  /// 녹음 진행 여부
  bool _isRecording = false;

  /// 녹음 시간 측정을 위한 타이머
  Timer? _recordingTimer;

  /// 녹음기 리소스가 선초기화되었는지 여부
  /// true: 권한이 허용된 상태에서 워밍업이 완료되어 첫 녹음 시 네이티브 준비 지연이 없습니다.
  /// false: 권한이 없거나 아직 워밍업되지 않아 첫 녹음 시 네이티브 준비 지연이 발생할 수 있습니다.
  bool _hasPrimedRecorderResources = false;

  /// 녹음기 워밍업이 진행 중인 경우 해당 Future를 참조하여 중복 워밍업을 방지합니다.
  Future<void>? _recorderWarmupInFlight;

  // ==================== Getters ====================

  /// 현재 재생 중인 오디오 URL
  String? get currentAudioUrl => _currentAudioUrl;

  /// 재생 중인지 여부
  bool get isPlaying => _isPlaying;

  /// 로딩 중인지 여부
  bool get isLoading => _isLoading;

  /// 현재 재생 위치
  Duration get currentPosition => _currentPosition;

  /// 총 재생 시간
  Duration get totalDuration => _totalDuration;

  /// 재생 진행률 (0.0 ~ 1.0)
  double get progress {
    if (_totalDuration == Duration.zero) return 0.0;
    return (_currentPosition.inMilliseconds / _totalDuration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  /// 에러 메시지
  String? get error => _error;

  // ==================== 녹음 관련 Getters ====================

  /// 현재 녹음된 파일 경로
  String? get currentRecordingPath => _currentRecordingPath;

  /// 녹음 시간 (초)
  int get recordingDuration => _recordingDuration;

  /// 녹음 진행 여부
  bool get isRecording => _isRecording;

  /// 포맷된 녹음 시간 (MM:SS)
  String get formattedRecordingDuration {
    final minutes = (_recordingDuration ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordingDuration % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // ==================== 재생 제어 ====================

  /// 오디오 재생
  Future<void> play(String audioUrl) async {
    try {
      _setLoading(true);
      _clearError();

      // 같은 URL이 재생 중이면 재개
      if (_currentAudioUrl == audioUrl && _audioPlayer != null) {
        await _audioPlayer!.resume();
        _isPlaying = true;
        _setLoading(false);
        notifyListeners();
        return;
      }

      // 다른 오디오가 재생 중이면 정지
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
        await _disposePlayer();
      }

      // 새 플레이어 생성
      _audioPlayer = ap.AudioPlayer();
      _currentAudioUrl = audioUrl;

      // 스트림 리스너 설정
      _setupListeners();

      // 재생 시작
      await _audioPlayer!.play(ap.UrlSource(audioUrl));
      _isPlaying = true;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('오디오 재생 실패: $e');
      _setLoading(false);
    }
  }

  /// 일시정지
  Future<void> pause() async {
    try {
      if (_audioPlayer != null && _isPlaying) {
        await _audioPlayer!.pause();
        _isPlaying = false;
        notifyListeners();
      }
    } catch (e) {
      _setError('일시정지 실패: $e');
    }
  }

  /// 재생/일시정지 토글
  Future<void> togglePlayPause(String audioUrl) async {
    if (_currentAudioUrl == audioUrl && _isPlaying) {
      await pause();
    } else {
      await play(audioUrl);
    }
  }

  /// 정지
  Future<void> stop() async {
    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
        _isPlaying = false;
        _currentPosition = Duration.zero;
        notifyListeners();
      }
    } catch (e) {
      _setError('정지 실패: $e');
    }
  }

  /// 특정 위치로 이동
  Future<void> seek(Duration position) async {
    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.seek(position);
        _currentPosition = position;
        notifyListeners();
      }
    } catch (e) {
      _setError('탐색 실패: $e');
    }
  }

  /// 특정 URL이 현재 재생 중인지 확인
  bool isUrlPlaying(String audioUrl) {
    return _currentAudioUrl == audioUrl && _isPlaying;
  }

  // ==================== 내부 메서드 ====================

  void _setupListeners() {
    _positionSubscription = _audioPlayer!.onPositionChanged.listen((position) {
      _currentPosition = position;
      notifyListeners();
    });

    _durationSubscription = _audioPlayer!.onDurationChanged.listen((duration) {
      _totalDuration = duration;
      notifyListeners();
    });

    _stateSubscription = _audioPlayer!.onPlayerStateChanged.listen((state) {
      _isPlaying = state == ap.PlayerState.playing;

      // 재생 완료 시 초기화
      if (state == ap.PlayerState.completed) {
        _currentPosition = Duration.zero;
        _isPlaying = false;
      }

      notifyListeners();
    });
  }

  Future<void> _disposePlayer() async {
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _stateSubscription?.cancel();

    _positionSubscription = null;
    _durationSubscription = null;
    _stateSubscription = null;

    await _audioPlayer?.dispose();
    _audioPlayer = null;
    _currentAudioUrl = null;
    _currentPosition = Duration.zero;
    _totalDuration = Duration.zero;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    debugPrint('ApiCommentAudioController Error: $message');
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  // ==================== 녹음 관련 메서드 (photo_editor_screen 호환성) ====================

  /// primeRecorderIfPermitted는 앱 진입 시 녹음 권한이 허용된 경우 녹음기 리소스를 선초기화하여
  /// 첫 녹음 시 네이티브 준비 지연이 없도록 보장합니다. 권한이 없거나 이미 워밍업된 경우에는 빠르게 반환합니다.
  Future<void> primeRecorderIfPermitted() async {
    final microphoneStatus = await _loadMicrophonePermissionStatus();
    if (!microphoneStatus.isGranted || _hasPrimedRecorderResources) {
      return;
    }

    // 이미 워밍업이 진행 중인 경우 해당 Future를 반환하여 중복 워밍업을 방지합니다.
    final inFlight = _recorderWarmupInFlight;

    //
    if (inFlight != null) {
      return inFlight;
    }

    // 실제 워밍업 작업을 시작하고 상태를 추적합니다.
    final future = _primeRecorderResourcesIfNeeded();
    _recorderWarmupInFlight = future;

    try {
      await future;
    } finally {
      if (identical(_recorderWarmupInFlight, future)) {
        _recorderWarmupInFlight = null;
      }
    }
  }

  /// _primeRecorderResourcesIfNeeded는 플랫폼별 녹음기 준비를 호출하고
  /// 앱 세션 동안 한 번만 워밍업되도록 상태를 캐시합니다.
  Future<void> _primeRecorderResourcesIfNeeded() async {
    try {
      await _primeRecorderResources(); // 플랫폼별 녹음기 준비 호출
      _hasPrimedRecorderResources = true; // 워밍업 완료 상태 캐시
    } on PlatformException catch (e) {
      if (e.code != 'unimplemented') {
        debugPrint('녹음기 선초기화 실패: ${e.message}');
      }
    } catch (e) {
      debugPrint('녹음기 선초기화 실패: $e');
    }
  }

  /// 네이티브 녹음 시작
  Future<void> startRecording() async {
    if (_isRecording) {
      // stale 상태를 자동 복구한 뒤 재시작
      debugPrint('녹음 상태가 남아 있어 강제 중지 후 재시작합니다.');
      try {
        await stopRecordingSimple(force: true);
      } catch (_) {
        // 강제 중지 실패 시 내부 상태를 초기화하고 재시도
        clearCurrentRecording();
      }
    }

    final hasPermission = await _requestMicrophonePermission();
    if (!hasPermission) {
      _setError('마이크 권한이 필요합니다.');
      throw Exception('마이크 권한이 필요합니다.');
    }

    try {
      final recordingPath = await _createRecordingFilePath();
      final startedPath = await _recorderChannel.invokeMethod<String>(
        'startRecording',
        {'filePath': recordingPath},
      );

      _currentRecordingPath = (startedPath != null && startedPath.isNotEmpty)
          ? startedPath
          : recordingPath;

      _recordingDuration = 0;
      _isRecording = true;
      _startRecordingTimer();
      notifyListeners();
      debugPrint('🎤 네이티브 녹음 시작: $_currentRecordingPath');
    } catch (e) {
      _setError('네이티브 녹음 시작 실패: $e');
      rethrow;
    }
  }

  /// 네이티브 녹음을 중지하고 파일 경로를 반환합니다.
  Future<void> stopRecordingSimple({bool force = false}) async {
    if (!_isRecording && !force) {
      debugPrint('녹음이 진행 중이 아닙니다.');
      return;
    }

    try {
      final stoppedPath = await _recorderChannel.invokeMethod<String>(
        'stopRecording',
      );

      if (stoppedPath != null && stoppedPath.isNotEmpty) {
        _currentRecordingPath = stoppedPath;
      }

      debugPrint('네이티브 녹음 중지: $_currentRecordingPath');
    } catch (e) {
      _setError('네이티브 녹음 중지 실패: $e');
      rethrow;
    } finally {
      _isRecording = false;
      _stopRecordingTimer();
      notifyListeners();
    }
  }

  /// initialize는 편집 화면이 붙기 전에 녹음기 워밍업을 재사용하거나 보완해
  /// 첫 오디오 녹음 시 네이티브 준비 지연이 남지 않도록 보장합니다.
  Future<void> initialize() async {
    await primeRecorderIfPermitted();
    debugPrint('✅ API AudioController 초기화 완료');
  }

  /// 실시간 오디오 정지
  ///
  /// 현재 재생 중인 오디오를 정지하고 상태를 초기화합니다
  Future<void> stopRealtimeAudio() async {
    if (_audioPlayer != null) {
      await _audioPlayer!.stop();
      _isPlaying = false;
      _currentPosition = Duration.zero;
      debugPrint('🛑 실시간 오디오 정지');
      notifyListeners();
    }
  }

  /// 현재 녹음 상태 초기화
  ///
  /// 녹음 경로와 녹음 시간을 초기화합니다
  /// photo_editor_screen이 화면을 나갈 때 호출됩니다
  void clearCurrentRecording() {
    _currentRecordingPath = null;
    _recordingDuration = 0;
    _isRecording = false;
    _stopRecordingTimer();
    debugPrint('🧹 녹음 상태 초기화');
    notifyListeners();
  }

  Future<bool> _requestMicrophonePermission() async {
    try {
      final granted = await _recorderChannel.invokeMethod<bool>(
        'requestMicrophonePermission',
      );
      return granted ?? false;
    } catch (e) {
      debugPrint('마이크 권한 요청 실패: $e');
      return false;
    }
  }

  Future<String> _createRecordingFilePath() async {
    final tempDir = await getTemporaryDirectory();
    return '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _recordingDuration += 1;
      notifyListeners();
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  // ==================== Lifecycle ====================

  @override
  void dispose() {
    _stopRecordingTimer();
    _disposePlayer();
    super.dispose();
  }
}
