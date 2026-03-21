import 'dart:async';
import 'dart:collection';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:soi/utils/snackbar_utils.dart';

abstract class CommentAudioPlayer {
  Stream<Duration> get onPositionChanged;
  Stream<Duration> get onDurationChanged;
  Stream<ap.PlayerState> get onPlayerStateChanged;

  Future<void> play(String audioUrl);
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> resume();
  Future<void> dispose();
}

typedef CommentAudioPlayerFactory = CommentAudioPlayer Function();

class _AudioplayersCommentAudioPlayer implements CommentAudioPlayer {
  _AudioplayersCommentAudioPlayer() : _player = ap.AudioPlayer();

  final ap.AudioPlayer _player;

  @override
  Stream<Duration> get onPositionChanged => _player.onPositionChanged;

  @override
  Stream<Duration> get onDurationChanged => _player.onDurationChanged;

  @override
  Stream<ap.PlayerState> get onPlayerStateChanged =>
      _player.onPlayerStateChanged;

  @override
  Future<void> play(String audioUrl) {
    return _player.play(ap.UrlSource(audioUrl));
  }

  @override
  Future<void> pause() {
    return _player.pause();
  }

  @override
  Future<void> stop() {
    return _player.stop();
  }

  @override
  Future<void> seek(Duration position) {
    return _player.seek(position);
  }

  @override
  Future<void> resume() {
    return _player.resume();
  }

  @override
  Future<void> dispose() {
    return _player.dispose();
  }
}

/// 음성 댓글 전용 오디오 컨트롤러
///
/// 각 음성 댓글의 개별 재생/일시정지를 관리합니다.
/// 기존 AudioController와 독립적으로 동작하여 댓글별 오디오 재생을 담당합니다.
class CommentAudioController extends ChangeNotifier {
  static const Duration _positionNotifyThreshold = Duration(milliseconds: 200);

  final CommentAudioPlayerFactory _playerFactory;

  CommentAudioController({CommentAudioPlayerFactory? playerFactory})
    : _playerFactory = playerFactory ?? _AudioplayersCommentAudioPlayer.new;

  // ==================== 상태 관리 ====================

  /// 댓글 ID별 AudioPlayer 인스턴스
  final Map<String, CommentAudioPlayer> _commentPlayers = {};
  final Map<String, List<StreamSubscription<dynamic>>> _playerSubscriptions =
      {};

  /// 댓글 ID별 재생 상태
  final Map<String, bool> _isPlayingStates = {};

  /// 댓글 ID별 현재 재생 위치
  final Map<String, Duration> _currentPositions = {};
  final Map<String, Duration> _lastNotifiedPositions = {};

  /// 댓글 ID별 총 재생 시간
  final Map<String, Duration> _totalDurations = {};

  /// 댓글 ID별 오디오 URL 캐시
  final Map<String, String> _commentAudioUrls = {};

  /// 현재 재생 중인 댓글 ID
  String? _currentPlayingCommentId;

  /// 로딩 상태
  bool _isLoading = false;

  /// 에러 메시지
  String? _error;

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  void _notifyIfChanged(bool changed) {
    if (changed) {
      notifyListeners();
    }
  }

  bool _setLoadingValue(bool loading) {
    if (_isLoading == loading) return false;
    _isLoading = loading;
    return true;
  }

  bool _setErrorValue(String? error) {
    if (_error == error) return false;
    _error = error;
    return true;
  }

  bool _setPlayingState(String commentId, bool isPlaying) {
    final previous = _isPlayingStates[commentId] ?? false;
    if (previous == isPlaying) return false;
    _isPlayingStates[commentId] = isPlaying;
    return true;
  }

  bool _setCommentPosition(
    String commentId,
    Duration position, {
    bool forceNotify = false,
  }) {
    final previous = _currentPositions[commentId] ?? Duration.zero;
    if (previous == position) return false;

    _currentPositions[commentId] = position;
    if (forceNotify) {
      _lastNotifiedPositions[commentId] = position;
      return true;
    }

    final lastNotified = _lastNotifiedPositions[commentId] ?? Duration.zero;
    if (lastNotified == Duration.zero || position == Duration.zero) {
      _lastNotifiedPositions[commentId] = position;
      return true;
    }

    final shouldNotify =
        (position.inMilliseconds - lastNotified.inMilliseconds).abs() >=
        _positionNotifyThreshold.inMilliseconds;
    if (shouldNotify) {
      _lastNotifiedPositions[commentId] = position;
    }
    return shouldNotify;
  }

  bool _setCommentDuration(String commentId, Duration duration) {
    final previous = _totalDurations[commentId];
    if (previous == duration) return false;
    _totalDurations[commentId] = duration;
    return true;
  }

  // ==================== Getters ====================

  /// 현재 재생 중인 댓글 ID
  String? get currentPlayingCommentId => _currentPlayingCommentId;

  /// 현재 어떤 댓글이라도 재생 중인지 확인
  bool get hasAnyPlaying => _isPlayingStates.values.any((playing) => playing);

  /// 로딩 상태
  bool get isLoading => _isLoading;

  /// 에러 메시지
  String? get error => _error;

  /// 특정 댓글이 재생 중인지 확인
  bool isCommentPlaying(String commentId) {
    return _isPlayingStates[commentId] ?? false;
  }

  /// 특정 댓글의 현재 재생 위치
  Duration getCommentPosition(String commentId) {
    return _currentPositions[commentId] ?? Duration.zero;
  }

  /// 특정 댓글의 총 재생 시간
  Duration getCommentDuration(String commentId) {
    return _totalDurations[commentId] ?? Duration.zero;
  }

  /// 특정 댓글의 재생 진행률 (0.0 ~ 1.0)
  double getCommentProgress(String commentId) {
    final position = getCommentPosition(commentId);
    final duration = getCommentDuration(commentId);

    if (duration == Duration.zero) return 0.0;

    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  // ==================== 기본 메서드 ====================

  /// 특정 댓글 재생
  Future<void> playComment(String commentId, String audioUrl) async {
    var changed = _setLoadingValue(true);
    changed = _setErrorValue(null) || changed;
    _notifyIfChanged(changed);

    try {
      if (_currentPlayingCommentId != null &&
          _currentPlayingCommentId != commentId) {
        await _stopCurrentPlaying(notify: false);
      }

      final player = await _getOrCreatePlayer(commentId, audioUrl);

      await player.play(audioUrl);

      changed = _setPlayingState(commentId, true) || changed;
      if (_currentPlayingCommentId != commentId) {
        _currentPlayingCommentId = commentId;
        changed = true;
      }
      _commentAudioUrls[commentId] = audioUrl;
    } catch (e) {
      _debugLog('CommentAudio - 재생 오류: $e');
      _setError('음성 댓글을 재생할 수 없습니다: $e');
    } finally {
      changed = _setLoadingValue(false) || changed;
      _notifyIfChanged(changed);
    }
  }

  /// 특정 댓글 일시정지
  Future<void> pauseComment(String commentId) async {
    try {
      final player = _commentPlayers[commentId];
      if (player != null) {
        await player.pause();
        final changed = _setPlayingState(commentId, false);
        _notifyIfChanged(changed);
      }
    } catch (e) {
      _debugLog('CommentAudio - 일시정지 오류: $e');
    }
  }

  /// 특정 댓글 중지
  Future<void> stopComment(String commentId) async {
    try {
      await _stopCommentInternal(commentId, notify: true);
    } catch (e) {
      _debugLog('CommentAudio - 중지 오류: $e');
    }
  }

  /// 특정 댓글 재생/일시정지 토글
  Future<void> toggleComment(String commentId, String audioUrl) async {
    final isPlaying = isCommentPlaying(commentId);

    if (isPlaying) {
      await pauseComment(commentId);
      return;
    }

    final cachedAudioUrl = _commentAudioUrls[commentId];
    final hasCachedPlayer = _commentPlayers.containsKey(commentId);
    final hasResumePosition = getCommentPosition(commentId) > Duration.zero;
    if (hasCachedPlayer && cachedAudioUrl == audioUrl && hasResumePosition) {
      await resumeComment(commentId);
      return;
    }

    await playComment(commentId, audioUrl);
  }

  // ==================== Private 메서드 ====================

  /// AudioPlayer 인스턴스 생성 또는 가져오기
  Future<CommentAudioPlayer> _getOrCreatePlayer(
    String commentId,
    String audioUrl,
  ) async {
    if (_commentPlayers.containsKey(commentId)) {
      return _commentPlayers[commentId]!;
    }

    final player = _playerFactory();
    _commentPlayers[commentId] = player;
    _commentAudioUrls[commentId] = audioUrl;
    _setupPlayerListeners(commentId, player);

    return player;
  }

  /// 플레이어 리스너 설정
  void _setupPlayerListeners(String commentId, CommentAudioPlayer player) {
    final subscriptions = <StreamSubscription<dynamic>>[];

    subscriptions.add(
      player.onPositionChanged.listen((Duration position) {
        final changed = _setCommentPosition(commentId, position);
        _notifyIfChanged(changed);
      }),
    );

    subscriptions.add(
      player.onDurationChanged.listen((Duration duration) {
        final changed = _setCommentDuration(commentId, duration);
        _notifyIfChanged(changed);
      }),
    );

    subscriptions.add(
      player.onPlayerStateChanged.listen((ap.PlayerState state) {
        var changed = false;
        final isNowPlaying = state == ap.PlayerState.playing;
        changed = _setPlayingState(commentId, isNowPlaying) || changed;

        if (state == ap.PlayerState.completed) {
          changed = _setPlayingState(commentId, false) || changed;
          changed =
              _setCommentPosition(
                commentId,
                Duration.zero,
                forceNotify: true,
              ) ||
              changed;

          if (_currentPlayingCommentId == commentId) {
            _currentPlayingCommentId = null;
            changed = true;
          }
        }

        _notifyIfChanged(changed);
      }),
    );

    _playerSubscriptions[commentId] = subscriptions;
  }

  /// 현재 재생 중인 댓글 중지
  Future<void> _stopCurrentPlaying({required bool notify}) async {
    if (_currentPlayingCommentId != null) {
      await _stopCommentInternal(_currentPlayingCommentId!, notify: notify);
    }
  }

  /// 에러 설정
  void _setError(String error) {
    final changed = _setErrorValue(error);
    if (changed) {
      _debugLog('CommentAudio - 오류: $error');
    }
    _notifyIfChanged(changed);
  }

  // ==================== 고급 기능 메서드 ====================

  /// 특정 위치로 이동
  Future<void> seekToPosition(String commentId, Duration position) async {
    try {
      final player = _commentPlayers[commentId];
      if (player != null) {
        await player.seek(position);
        final changed = _setCommentPosition(
          commentId,
          position,
          forceNotify: true,
        );
        _notifyIfChanged(changed);
      }
    } catch (e) {
      _debugLog('CommentAudio - 위치 이동 오류: $e');
    }
  }

  /// 재생 재개 (일시정지된 댓글 재개)
  Future<void> resumeComment(String commentId) async {
    try {
      final player = _commentPlayers[commentId];
      if (player != null && !isCommentPlaying(commentId)) {
        if (_currentPlayingCommentId != null &&
            _currentPlayingCommentId != commentId) {
          await _stopCurrentPlaying(notify: false);
        }

        await player.resume();

        var changed = _setPlayingState(commentId, true);
        if (_currentPlayingCommentId != commentId) {
          _currentPlayingCommentId = commentId;
          changed = true;
        }
        _notifyIfChanged(changed);
      }
    } catch (e) {
      _debugLog('CommentAudio - 재생 재개 오류: $e');
    }
  }

  /// 모든 댓글의 재생 상태 정보 반환
  Map<String, bool> getAllPlayingStates() {
    return UnmodifiableMapView(_isPlayingStates);
  }

  /// 특정 댓글의 오디오 URL 반환
  String? getCommentAudioUrl(String commentId) {
    return _commentAudioUrls[commentId];
  }

  /// 현재 로드된 댓글 수 반환
  int get loadedCommentsCount => _commentPlayers.length;

  // ==================== 정리 메서드 ====================

  /// 모든 댓글 재생 중지
  Future<void> stopAllComments() async {
    var changed = false;
    for (final commentId in _commentPlayers.keys.toList(growable: false)) {
      changed = await _stopCommentInternal(commentId, notify: false) || changed;
    }
    _notifyIfChanged(changed);
  }

  /// 특정 댓글의 플레이어 해제
  Future<void> disposeCommentPlayer(String commentId) async {
    final player = _commentPlayers[commentId];
    if (player == null) {
      return;
    }

    await _stopCommentInternal(commentId, notify: false);
    await _disposePlayerResources(commentId);
    _debugLog('CommentAudio - 플레이어 해제: $commentId');
    notifyListeners();
  }

  /// 에러 상태를 사용자에게 보여주고 자동으로 클리어
  void showErrorToUser(BuildContext context) {
    if (_error != null) {
      SnackBarUtils.showSnackBar(
        context,
        _error!,
        duration: const Duration(seconds: 3),
      );
      final changed = _setErrorValue(null);
      _notifyIfChanged(changed);
    }
  }

  Future<bool> _stopCommentInternal(
    String commentId, {
    required bool notify,
  }) async {
    final player = _commentPlayers[commentId];
    if (player == null) {
      return false;
    }

    await player.stop();

    var changed = false;
    changed = _setPlayingState(commentId, false) || changed;
    changed =
        _setCommentPosition(commentId, Duration.zero, forceNotify: true) ||
        changed;

    if (_currentPlayingCommentId == commentId) {
      _currentPlayingCommentId = null;
      changed = true;
    }

    if (notify) {
      _notifyIfChanged(changed);
    }
    return changed;
  }

  Future<void> _disposePlayerResources(String commentId) async {
    final subscriptions = _playerSubscriptions.remove(commentId);
    if (subscriptions != null) {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    }

    final player = _commentPlayers.remove(commentId);
    if (player != null) {
      await player.dispose();
    }

    _isPlayingStates.remove(commentId);
    _currentPositions.remove(commentId);
    _lastNotifiedPositions.remove(commentId);
    _totalDurations.remove(commentId);
    _commentAudioUrls.remove(commentId);

    if (_currentPlayingCommentId == commentId) {
      _currentPlayingCommentId = null;
    }
  }

  @override
  void dispose() {
    for (final subscriptions in _playerSubscriptions.values) {
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
    }
    _playerSubscriptions.clear();

    for (final player in _commentPlayers.values) {
      unawaited(player.dispose());
    }
    _commentPlayers.clear();
    _isPlayingStates.clear();
    _currentPositions.clear();
    _lastNotifiedPositions.clear();
    _totalDurations.clear();
    _commentAudioUrls.clear();
    _currentPlayingCommentId = null;

    super.dispose();
  }
}
