import 'dart:async';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

import '../../../api/controller/audio_controller.dart';
import '../../../utils/snackbar_utils.dart';
import '../../about_archiving/widgets/wave_form_widget/custom_waveform_widget.dart';

class CommentAudioSheetResult {
  final String audioPath;
  final List<double> waveformData;
  final int durationMs;

  const CommentAudioSheetResult({
    required this.audioPath,
    required this.waveformData,
    required this.durationMs,
  });
}

enum _CommentAudioSheetState { ready, recording, playback }

/// 댓글 작성 시 음성 댓글 녹음과 재생을 담당하는 하단 시트 위젯입니다.
class CommentAudioRecordingBottomSheetWidget extends StatefulWidget {
  const CommentAudioRecordingBottomSheetWidget({super.key});

  @override
  State<CommentAudioRecordingBottomSheetWidget> createState() =>
      _CommentAudioRecordingBottomSheetWidgetState();
}

class _CommentAudioRecordingBottomSheetWidgetState
    extends State<CommentAudioRecordingBottomSheetWidget> {
  // sp 단위로 설정해야 내부 콘텐츠(.sp 기반)와 함께 스케일되어
  // 어떤 디바이스에서도 오버플로가 발생하지 않습니다.
  double get _sheetHeight => 310.sp;

  /// 녹음 중과 재생 중에 동일한 높이로 파형이 표시되도록, 두 모드에서 모두 적절한 높이로 설정합니다.
  double get _waveformHeight => 80.sp;

  late final AudioController _audioController;
  late final RecorderController _recorderController;
  PlayerController? _playerController;

  _CommentAudioSheetState _state = _CommentAudioSheetState.ready;
  List<double> _waveformData = const [];
  String? _audioPath;
  DateTime? _recordingStartedAt;
  int _recordingDurationMs = 0;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _audioController = context.read<AudioController>();
    _recorderController = RecorderController(useLegacyNormalization: false)
      ..overrideAudioSession = false
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
      ..sampleRate = 44100
      ..updateFrequency = const Duration(milliseconds: 50);
    _recorderController.checkPermission();
    _playerController = PlayerController();
  }

  @override
  void dispose() {
    unawaited(_stopRecordingIfNeeded(force: true));
    unawaited(_stopWaveformRecordingIfNeeded());
    unawaited(_stopPlaybackIfNeeded());
    _recorderController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_isTransitioning || _state == _CommentAudioSheetState.recording) {
      return;
    }

    _isTransitioning = true;
    try {
      // 이전 사이클의 잔여 상태를 먼저 정리
      await _stopPlaybackIfNeeded();
      await _stopRecordingIfNeeded(force: true);
      await _stopWaveformRecordingIfNeeded();
      _audioController.clearCurrentRecording();

      // waveform UI와 실제 녹음을 함께 시작한다.
      await _recorderController.record();
      await _audioController.startRecording();

      _recordingStartedAt = DateTime.now();
      if (!mounted) {
        return;
      }
      setState(() {
        _audioPath = null;
        _waveformData = const [];
        _recordingDurationMs = 0;
        _state = _CommentAudioSheetState.recording;
      });
    } catch (_) {
      // 부분 시작 실패 시 즉시 롤백
      await _stopRecordingIfNeeded(force: true);
      await _stopWaveformRecordingIfNeeded();
      _audioController.clearCurrentRecording();
      if (mounted) {
        setState(() {
          _audioPath = null;
          _waveformData = const [];
          _recordingStartedAt = null;
          _recordingDurationMs = 0;
          _state = _CommentAudioSheetState.ready;
        });
      }
      _showSnackBar(tr('comments.audio_sheet.recording_failed'));
    } finally {
      _isTransitioning = false;
    }
  }

  Future<void> _stopRecordingAndPreparePlayback() async {
    if (_isTransitioning || _state != _CommentAudioSheetState.recording) {
      return;
    }

    _isTransitioning = true;
    try {
      var waveform = List<double>.from(
        _recorderController.waveData,
      ); // 녹음 중에 수집된 웨이브폼 데이터입니다. 음성의 양에 따라 100개 이상의 샘플이 있을 수 있습니다.

      if (waveform.isNotEmpty) {
        // 음성의 양에 따라 음성의 절대값이 매우 작게 나오는 경우가 있어서, 웨이브폼 데이터의 절대값을 취해서 보정해줍니다.
        waveform = waveform.map((value) => value.abs()).toList();
      }

      await _stopWaveformRecordingIfNeeded(); // 먼저 웨이브폼 녹음을 중지해서 더 이상 웨이브폼 데이터가 수집되지 않도록 합니다.

      // 네이티브 녹음도 중지합니다. force: true로 해서 녹음이 진행 중이지 않은 경우에도 내부 상태를 초기화하도록 합니다.
      await _audioController.stopRecordingSimple(force: true);

      // 녹음이 중지된 후에 실제 녹음된 파일 경로를 가져옵니다.
      // stopRecordingSimple이 정상적으로 녹음을 중지했다면 currentRecordingPath에 녹음된 파일의 경로가 설정되어 있을 것입니다.
      final path = _audioController.currentRecordingPath;
      if (path == null || path.isEmpty) {
        throw StateError('recording path is empty');
      }

      final durationMs = _recordingStartedAt == null
          ? 0
          : DateTime.now().difference(_recordingStartedAt!).inMilliseconds;
      _recordingDurationMs = durationMs;

      await _stopPlaybackIfNeeded();
      final player = PlayerController();
      _playerController = player;
      await player.preparePlayer(path: path, shouldExtractWaveform: true);

      if (waveform.isEmpty) {
        final extracted = await player.extractWaveformData(
          path: path,
          noOfSamples: 100,
        );
        if (extracted.isNotEmpty) {
          waveform = extracted;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _audioPath = path;
        _waveformData = waveform;
        _state = _CommentAudioSheetState.playback;
      });
    } catch (_) {
      _showSnackBar(tr('comments.audio_sheet.prepare_failed'));
      await _discardRecordingAndReset();
    } finally {
      _isTransitioning = false;
    }
  }

  Future<void> _togglePlayback() async {
    final player = _playerController;
    final path = _audioPath;
    if (player == null || path == null || path.isEmpty) {
      return;
    }

    try {
      if (player.playerState.isPlaying) {
        await player.pausePlayer();
      } else {
        if (player.playerState == PlayerState.initialized ||
            player.playerState == PlayerState.paused) {
          await player.startPlayer();
        } else {
          await player.preparePlayer(path: path, shouldExtractWaveform: true);
          await player.startPlayer();
        }
      }
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      _showSnackBar(tr('common.error_occurred'));
    }
  }

  Future<void> _backToReady() async {
    await _discardRecordingAndReset();
  }

  Future<void> _stopRecordingIfNeeded({bool force = false}) async {
    if (force || _audioController.isRecording) {
      try {
        await _audioController.stopRecordingSimple(force: force);
      } catch (_) {}
    }
  }

  Future<void> _stopWaveformRecordingIfNeeded() async {
    if (!_recorderController.isRecording) {
      return;
    }

    try {
      await _recorderController.stop();
    } catch (_) {}
  }

  Future<void> _stopPlaybackIfNeeded() async {
    final player = _playerController;
    if (player == null) {
      return;
    }

    try {
      await player.stopPlayer();
    } catch (_) {}

    try {
      player.dispose();
    } catch (_) {}

    if (identical(_playerController, player)) {
      _playerController = null;
    }
  }

  Future<void> _discardRecordingAndReset() async {
    await _stopPlaybackIfNeeded();
    await _stopRecordingIfNeeded(force: true);
    await _stopWaveformRecordingIfNeeded();

    final oldPath = _audioPath ?? _audioController.currentRecordingPath;
    _audioController.clearCurrentRecording();

    if (oldPath != null && oldPath.isNotEmpty) {
      try {
        final file = File(oldPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _audioPath = null;
      _waveformData = const [];
      _recordingStartedAt = null;
      _recordingDurationMs = 0;
      _state = _CommentAudioSheetState.ready;
    });
  }

  Future<void> _confirm() async {
    final path = _audioPath;
    if (path == null || path.isEmpty) {
      return;
    }

    await _stopPlaybackIfNeeded();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(
      CommentAudioSheetResult(
        audioPath: path,
        waveformData: List<double>.from(_waveformData),
        durationMs: _recordingDurationMs,
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    SnackBarUtils.showSnackBar(context, message);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// 상단 바를 빌드하는 메서드입니다. 상태에 따라 다른 버튼 구성을 보여줍니다.
  /// - ready 상태에서는 닫기 버튼만 보여줍니다.
  /// - recording과 playback 상태에서는 뒤로 가기 버튼과, playback 상태에서는 추가로 확인 버튼을 보여줍니다.
  Widget _buildTopBar() {
    switch (_state) {
      case _CommentAudioSheetState.ready:
        return Row(
          children: [
            Padding(
              padding: EdgeInsets.only(left: (7.96).sp, top: (7.96).sp),
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: SvgPicture.asset(
                  "assets/cancel.svg",
                  width: (30.08).sp,
                  height: (30.08).sp,
                ),
              ),
            ),
          ],
        );
      case _CommentAudioSheetState.recording:
      case _CommentAudioSheetState.playback:
        return Row(
          children: [
            Padding(
              padding: EdgeInsets.only(left: (7.96).sp, top: (7.96).sp),
              child: IconButton(
                onPressed: _backToReady,
                icon: const Icon(
                  Icons.chevron_left,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),
            const Spacer(),
            if (_state == _CommentAudioSheetState.playback)
              Padding(
                padding: EdgeInsets.only(right: (15.96).sp, top: (7.96).sp),
                child: SizedBox(
                  height: 29.sp,
                  child: TextButton(
                    onPressed: _confirm,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      alignment: Alignment.center,
                      padding: EdgeInsets.symmetric(horizontal: 12.sp),

                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      tr('common.confirm'),
                      style: TextStyle(
                        color: Color(0xFF1C1C1C),
                        fontSize: 13,
                        fontFamily: 'Pretendard Variable',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
    }
  }

  /// 녹음 시작 전 초기 UI
  Widget _buildReadyBody() {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset("assets/waveform_icon.png", width: 93.sp, height: 93.sp),
          SizedBox(height: 5.sp),
          Text(
            tr('comments.audio_sheet.start_tag'),
            style: TextStyle(
              color: Color(0xFFCBCBCB),
              fontSize: 16.sp,
              fontFamily: 'Pretendard Variable',
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 10.sp),
          // 녹음 시작 버튼
          IconButton(
            onPressed: _startRecording,
            icon: SvgPicture.asset(
              'assets/record_icon.svg',
              width: 54.sp,
              height: 54.sp,
            ),
          ),
        ],
      ),
    );
  }

  /// 녹음 중 UI
  Widget _buildRecordingBody() {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(left: 42.sp, right: 42.sp),
        child: Column(
          children: [
            // 녹음된 시간 표시
            Selector<AudioController, String>(
              selector: (_, controller) =>
                  controller.formattedRecordingDuration,
              builder: (_, duration, __) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A3A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    duration,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.40,
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 20.sp),
            // 녹음 중인 파형을 보여주는 위젯
            AudioWaveforms(
              size: Size(double.infinity, _waveformHeight),
              recorderController: _recorderController,

              waveStyle: const WaveStyle(
                waveColor: Colors.white,
                showMiddleLine: false, // 가운데 기준선은 보이지 않도록 합니다.
                extendWaveform: true, // 녹음 중인 파형이 컨테이너 끝까지 이어지도록 합니다.
                scaleFactor: 40, // 녹음 중인 파형이 더 역동적으로 보이도록 스케일을 키웁니다.
                waveCap: StrokeCap.round, // 녹음 중인 파형의 끝 모양을 둥글게 합니다.
                spacing: 7, // 녹음 중인 파형의 간격을 조금 더 넓게 합니다.
              ),
            ),

            SizedBox(height: 40.sp),
            // 녹음 취소 버튼과 녹음 완료 버튼이 배치된 영역
            Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: _backToReady,
                    icon: Image.asset(
                      'assets/trash_comment.png',
                      width: 33.sp,
                      height: 33.sp,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _stopRecordingAndPreparePlayback,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3F3F3F),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.pause,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 녹음이 완료된 후 보여지는 재생 UI의 본문을 빌드하는 메서드입니다.
  Widget _buildPlaybackBody() {
    final player = _playerController;
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(left: 42.sp, right: 42.sp),
        child: Column(
          children: [
            if (player == null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _formatDuration(Duration(milliseconds: _recordingDurationMs)),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'Pretendard Variable',
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.40,
                  ),
                ),
              )
            else
              StreamBuilder<int>(
                stream: player.onCurrentDurationChanged,
                builder: (context, snapshot) {
                  final currentDuration = Duration(
                    milliseconds: snapshot.data ?? 0,
                  );
                  final fallback = Duration(milliseconds: _recordingDurationMs);
                  final display = currentDuration == Duration.zero
                      ? fallback
                      : currentDuration;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3A3A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _formatDuration(display),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'Pretendard Variable',
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.40,
                      ),
                    ),
                  );
                },
              ),
            SizedBox(height: 20.sp),
            if (player == null || _waveformData.isEmpty)
              SizedBox(height: _waveformHeight)
            else
              StreamBuilder<int>(
                stream: player.onCurrentDurationChanged,
                builder: (context, snapshot) {
                  final current = snapshot.data ?? 0;
                  final total = player.maxDuration;
                  final progress = total > 0
                      ? (current / total).clamp(0.0, 1.0)
                      : 0.0;
                  return SizedBox(
                    height: _waveformHeight,
                    child: CustomWaveformWidget(
                      waveformData: _waveformData,
                      color: const Color(0xFF5A5A5A),
                      activeColor: Colors.white,
                      progress: progress,
                      barThickness: 3.0,
                      barSpacing: 7.0,
                      maxBarHeightFactor: 0.82,
                      amplitudeScale: 1.0,
                      minBarHeight: 0.0,
                      strokeCap: StrokeCap.round,
                    ),
                  );
                },
              ),
            SizedBox(height: 40.sp),

            // 녹음 취소 버튼과 재생/일시정지 버튼이 배치된 영역
            Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: _discardRecordingAndReset,
                    icon: Image.asset(
                      "assets/trash_comment.png",
                      width: 33.sp,
                      height: 33.sp,
                    ),
                  ),
                ),
                // 재생/일시정지 버튼
                GestureDetector(
                  onTap: _togglePlayback,
                  child: StreamBuilder<PlayerState>(
                    stream: player?.onPlayerStateChanged,
                    builder: (context, snapshot) {
                      final isPlaying =
                          (snapshot.data ?? player?.playerState)?.isPlaying ??
                          false;
                      return Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3F3F3F),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 30,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _state == _CommentAudioSheetState.ready,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _state != _CommentAudioSheetState.ready) {
          unawaited(_discardRecordingAndReset());
        }
      },
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _sheetHeight,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFF1F1F1F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.8)),
            ),
            child: Column(
              children: [
                _buildTopBar(),
                switch (_state) {
                  _CommentAudioSheetState.ready => _buildReadyBody(),
                  _CommentAudioSheetState.recording => _buildRecordingBody(),
                  _CommentAudioSheetState.playback => _buildPlaybackBody(),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}
