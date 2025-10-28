import 'dart:async';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../controllers/audio_controller.dart';
import '../../about_archiving/widgets/wave_form_widget/custom_waveform_widget.dart';

/// 음성 댓글 전용 위젯
///
/// 피드 화면에서 음성 댓글을 녹음하고 재생하는 기능을 제공합니다.
/// AudioRecorderWidget보다 단순하고 음성 댓글에 최적화되어 있습니다.
enum VoiceCommentState {
  idle, // 초기 상태 (녹음 버튼 표시)
  recording, // 녹음 중
  recorded, // 녹음 완료 (재생 가능)
  placing, // 프로필 배치 중 (드래그 가능)
  saved, // 저장 완료 (프로필 이미지 표시)
}

class VoiceCommentWidget extends StatefulWidget {
  final bool autoStart; // 자동 녹음 시작 여부
  final Function(String?, List<double>?, int?)?
  onRecordingCompleted; // 녹음 완료 콜백 (duration 추가)
  final VoidCallback? onRecordingDeleted; // 녹음 삭제 콜백
  final VoidCallback? onSaved; // 저장 완료 콜백 추가
  final Future<void> Function()? onSaveRequested; // 저장 요청 콜백 (파형 배치 확정 시)
  final VoidCallback? onSaveCompleted; // 저장 완료 후 위젯 초기화 콜백
  final String? profileImageUrl; // 프로필 이미지 URL 추가
  final bool startAsSaved; // 저장된 상태로 시작할지 여부
  final bool startInPlacingMode; // placing 모드로 시작할지 여부 (텍스트 댓글용)
  final Function(Offset)? onProfileImageDragged; // 프로필 이미지 드래그 콜백
  final bool enableMultipleComments; // 여러 댓글 지원 여부
  final bool hasExistingComments; // 기존 댓글 존재 여부

  const VoiceCommentWidget({
    super.key,
    this.autoStart = false,
    this.onRecordingCompleted,
    this.onRecordingDeleted,
    this.onSaved,
    this.onSaveRequested, // 저장 요청 콜백 추가
    this.onSaveCompleted, // 저장 완료 후 위젯 초기화 콜백 추가
    this.profileImageUrl, // 프로필 이미지 URL 추가
    this.startAsSaved = false, // 기본값은 false
    this.startInPlacingMode = false, // 기본값은 false
    this.onProfileImageDragged, // 드래그 콜백 추가
    this.enableMultipleComments = false, // 여러 댓글 지원 기본값 false
    this.hasExistingComments = false, // 기존 댓글 존재 기본값 false
  });

  @override
  State<VoiceCommentWidget> createState() => _VoiceCommentWidgetState();
}

class _VoiceCommentWidgetState extends State<VoiceCommentWidget> {
  late AudioController _audioController;
  late RecorderController _recorderController;
  PlayerController? _playerController;

  VoiceCommentState _currentState = VoiceCommentState.idle;
  List<double>? _waveformData;
  DateTime? _recordingStartTime; // 녹음 시작 시간 추가

  bool _isFinalizingPlacement = false; // 중복 저장 방지
  final GlobalKey _profileDraggableKey = GlobalKey();
  TapDownDetails? _pendingTapDownDetails;

  /// 이전 녹음 상태 (애니메이션 제어용)
  VoiceCommentState? _lastState;

  /// 외부에서 저장 완료를 알리는 메서드
  void markAsSaved() {
    if (mounted) {
      _markAsSaved();
    }
  }

  @override
  void initState() {
    super.initState();

    // 저장된 상태로 시작해야 하는 경우
    if (widget.startAsSaved) {
      _currentState = VoiceCommentState.saved;

      return; // 컨트롤러 초기화 없이 리턴
    }

    // Placing 모드로 시작해야 하는 경우 (텍스트 댓글용)
    if (widget.startInPlacingMode) {
      _currentState = VoiceCommentState.placing;
      debugPrint(
        '🟢 [VoiceCommentWidget] startInPlacingMode=true, placing 모드로 시작',
      );
      return; // 컨트롤러 초기화 없이 리턴
    }

    _initializeControllers();

    // autoStart는 saved/placing 상태가 아닐 때만 적용
    if (widget.autoStart && _currentState != VoiceCommentState.saved) {
      _currentState = VoiceCommentState.recording;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startRecording();
      });
    }
  }

  void _initializeControllers() {
    _audioController = Provider.of<AudioController>(context, listen: false);

    _recorderController =
        RecorderController()
          ..androidEncoder = AndroidEncoder.aac
          ..androidOutputFormat = AndroidOutputFormat.mpeg4
          ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
          ..sampleRate = 44100;

    _playerController = PlayerController();
  }

  @override
  void dispose() {
    // 저장된 상태가 아닌 경우에만 컨트롤러 해제
    if (_currentState != VoiceCommentState.saved) {
      _recorderController.dispose();
      _playerController?.dispose();
    }
    super.dispose();
  }

  /// 녹음 시작
  Future<void> _startRecording() async {
    try {
      // 녹음 시작 시간 기록
      _recordingStartTime = DateTime.now();

      await _recorderController.record();
      await _audioController.startRecording();

      setState(() {
        _lastState = _currentState;
        _currentState = VoiceCommentState.recording;
      });
    } catch (e) {
      setState(() {
        _lastState = _currentState;
        _currentState = VoiceCommentState.idle;
      });
    }
  }

  /// 녹음 중지 및 재생 준비
  Future<void> _stopAndPreparePlayback() async {
    try {
      // 파형 데이터 추출
      List<double> waveformData = List<double>.from(
        _recorderController.waveData,
      );
      if (waveformData.isNotEmpty) {
        waveformData = waveformData.map((value) => value.abs()).toList();
      }

      // 녹음 중지
      await _recorderController.stop();
      await _audioController.stopRecordingSimple();

      final filePath = _audioController.currentRecordingPath;
      if (filePath != null && filePath.isNotEmpty) {
        // 녹음 시간 계산
        final recordingDuration =
            _recordingStartTime != null
                ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
                : 0;

        // 재생 준비
        await _playerController?.preparePlayer(
          path: filePath,
          shouldExtractWaveform: true,
        );

        setState(() {
          _lastState = _currentState;
          _currentState = VoiceCommentState.recorded;
          _waveformData = waveformData;
        });

        // 콜백 호출 (duration 포함)
        widget.onRecordingCompleted?.call(
          filePath,
          waveformData,
          recordingDuration,
        );
      }
    } catch (e) {
      debugPrint('❌ 녹음 중지 오류: $e');
    }
  }

  /// 녹음 취소 (쓰레기통 클릭)
  void _deleteRecording() {
    try {
      // 재생 중이면 중지
      if (_playerController?.playerState.isPlaying == true) {
        _playerController?.stopPlayer();
      }

      // 상태 초기화
      setState(() {
        _lastState = _currentState;
        _currentState = VoiceCommentState.idle;
        _waveformData = null;
      });

      // 삭제 콜백 호출
      widget.onRecordingDeleted?.call();
    } catch (e) {
      debugPrint('녹음 삭제 오류: $e');
    }
  }

  /// 재생/일시정지 토글
  Future<void> _togglePlayback() async {
    // null 체크와 mounted 체크 추가
    if (!mounted || _playerController == null) {
      return;
    }

    try {
      if (_playerController!.playerState.isPlaying) {
        await _playerController!.pausePlayer();
        // debugPrint('재생 일시정지');
      } else {
        // 재생이 끝났다면 처음부터 다시 시작
        if (_playerController!.playerState.isStopped) {
          await _playerController!.startPlayer();
          // debugPrint('재생 시작 (처음부터)');
        } else {
          await _playerController!.startPlayer();
          // debugPrint('재생 시작');
        }
      }
      if (mounted) {
        setState(() {}); // UI 갱신
      }
    } catch (e) {
      // debugPrint('재생/일시정지 오류: $e');
    }
  }

  /// 프로필 배치 모드 진입
  void _enterPlacementMode(TapDownDetails details) {
    if (_waveformData == null || _waveformData!.isEmpty) {
      return;
    }

    setState(() {
      _lastState = _currentState;
      _currentState = VoiceCommentState.placing;
    });
    _pendingTapDownDetails = details;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final tapDetails = _pendingTapDownDetails;
      final draggableState = _profileDraggableKey.currentState;
      if (tapDetails == null || draggableState == null) {
        return;
      }

      _pendingTapDownDetails = null;
      final PointerDeviceKind deviceKind =
          tapDetails.kind ?? PointerDeviceKind.touch;
      final dynamic draggable = draggableState;
      final startDrag = draggable.startDrag;

      try {
        Function.apply(startDrag, [tapDetails.globalPosition, deviceKind]);
      } catch (_) {
        try {
          Function.apply(startDrag, [tapDetails.globalPosition]);
        } catch (_) {}
      }
    });
  }

  /// 프로필 배치 완료 처리
  Future<void> _finalizePlacement() async {
    if (_isFinalizingPlacement) {
      return;
    }

    _isFinalizingPlacement = true;

    try {
      if (widget.onSaveRequested != null) {
        await widget.onSaveRequested!.call();
      }

      if (!mounted) {
        return;
      }

      _markAsSaved();
      widget.onSaveCompleted?.call();
    } catch (e) {
      if (mounted) {
        // 저장 실패 시 다시 파형 모드로 복귀
        setState(() {
          _lastState = _currentState;
          _currentState = VoiceCommentState.recorded;
        });
      }
    } finally {
      _isFinalizingPlacement = false;
    }
  }

  /// 프로필 배치 취소 처리
  void _cancelPlacement() {
    if (!mounted) {
      return;
    }

    setState(() {
      _lastState = _currentState;
      _currentState = VoiceCommentState.recorded;
    });
  }

  /// 녹음 중 UI (AudioRecorderWidget과 동일)
  Widget _buildRecordingUI(String duration) {
    return Container(
      width: 353, // 텍스트 필드와 동일한 너비
      height: 46, // 텍스트 필드와 동일한 높이
      decoration: BoxDecoration(
        color: const Color(0xffd9d9d9).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(21.5),
        border: Border.all(
          color: const Color(0x66D9D9D9).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 15.w),
          // 쓰레기통 아이콘 (녹음 취소)
          GestureDetector(
            onTap: _deleteRecording,
            child: Image.asset('assets/trash.png', width: 25, height: 25),
          ),
          SizedBox(width: 18.w),
          // 실시간 파형
          Expanded(
            child: AudioWaveforms(
              size: Size(1, 46),
              recorderController: _recorderController,
              waveStyle: const WaveStyle(
                waveColor: Colors.white,
                extendWaveform: true,
                showMiddleLine: false,
              ),
            ),
          ),

          // 녹음 시간
          Text(
            duration,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'Pretendard Variable',
              fontWeight: FontWeight.w500,
              letterSpacing: -0.40,
            ),
          ),
          // 중지 버튼
          IconButton(
            onPressed: _stopAndPreparePlayback,
            padding: EdgeInsets.only(bottom: 3.h),
            icon: Icon(Icons.stop, color: Colors.white, size: 35.sp),
          ),
        ],
      ),
    );
  }

  /// 재생 UI (AudioRecorderWidget과 동일)
  Widget _buildPlaybackUI() {
    final borderRadius = BorderRadius.circular(21.5);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: 353,
      height: 46,
      decoration: BoxDecoration(borderRadius: borderRadius),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: borderRadius,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                transitionBuilder:
                    (child, animation) =>
                        FadeTransition(opacity: animation, child: child),

                child: Container(
                  key: ValueKey('playback_bg'),
                  decoration: BoxDecoration(
                    color: const Color(0xffd9d9d9).withValues(alpha: 0.1),
                    border: Border.all(
                      color: const Color(0x66D9D9D9).withValues(alpha: 0.4),
                      width: 1,
                    ),
                    borderRadius: borderRadius,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 15.w),
                // 쓰레기통 아이콘 (삭제)
                GestureDetector(
                  onTap: _deleteRecording,
                  child: Image.asset('assets/trash.png', width: 25, height: 25),
                ),
                SizedBox(width: 18.w),
                // 재생 파형 - 클릭 시 저장
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      // 파형 클릭 시 프로필 배치 모드로 전환 후 즉시 드래그 시작
                      _enterPlacementMode(details);
                    },
                    child:
                        _waveformData != null && _waveformData!.isNotEmpty
                            ? StreamBuilder<int>(
                              stream:
                                  _playerController?.onCurrentDurationChanged ??
                                  const Stream.empty(),
                              builder: (context, positionSnapshot) {
                                // mounted와 _playerController null 체크 추가
                                if (!mounted || _playerController == null) {
                                  return Container();
                                }

                                final currentPosition =
                                    positionSnapshot.data ?? 0;
                                final totalDuration =
                                    _playerController?.maxDuration ?? 1;
                                final progress =
                                    totalDuration > 0
                                        ? (currentPosition / totalDuration)
                                            .clamp(0.0, 1.0)
                                        : 0.0;

                                // _waveformData가 여전히 null이 아닌지 다시 확인
                                if (_waveformData == null ||
                                    _waveformData!.isEmpty) {
                                  return Container();
                                }

                                return CustomWaveformWidget(
                                  waveformData: _waveformData!,
                                  color: Colors.grey,
                                  activeColor: Colors.white,
                                  progress: progress,
                                );
                              },
                            )
                            : Container(
                              height: 46,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade700,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  '파형 없음',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 14.sp,
                                    fontFamily: "Pretendard",
                                  ),
                                ),
                              ),
                            ),
                  ),
                ),
                // 재생 시간
                StreamBuilder<int>(
                  stream:
                      _playerController?.onCurrentDurationChanged ??
                      const Stream.empty(),
                  builder: (context, snapshot) {
                    // mounted와 _playerController null 체크 추가
                    if (!mounted || _playerController == null) {
                      return Text(
                        '00:00',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'Pretendard Variable',
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.40,
                        ),
                      );
                    }

                    final currentDurationMs = snapshot.data ?? 0;
                    final currentDuration = Duration(
                      milliseconds: currentDurationMs,
                    );
                    final minutes = currentDuration.inMinutes;
                    final seconds = currentDuration.inSeconds % 60;
                    return Text(
                      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'Pretendard Variable',
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.40,
                      ),
                    );
                  },
                ),
                // 재생/일시정지 버튼
                StreamBuilder<PlayerState>(
                  stream:
                      _playerController?.onPlayerStateChanged ??
                      const Stream.empty(),
                  builder: (context, snapshot) {
                    // mounted와 _playerController null 체크 추가
                    if (!mounted || _playerController == null) {
                      return IconButton(
                        onPressed: null,
                        icon: Icon(
                          Icons.play_arrow,
                          color: Colors.white54,
                          size: 35.sp,
                        ),
                      );
                    }

                    final playerState = snapshot.data;
                    final isPlaying = playerState?.isPlaying ?? false;

                    return IconButton(
                      onPressed: _togglePlayback,
                      padding: EdgeInsets.only(bottom: 3.h),
                      icon: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 35.sp,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 저장 완료 상태로 변경
  void _markAsSaved() {
    // 애니메이션을 위해 _lastState 설정
    setState(() {
      _lastState = _currentState;
      _currentState = VoiceCommentState.saved;
    });

    // 상태 변경 후 컨트롤러들을 정리 (애니메이션 후에)
    Future.delayed(Duration(milliseconds: 400), () {
      if (mounted) {
        _cleanupControllers();
        setState(() {
          // 파형 데이터 정리
          _waveformData = null;
        });
      }
    });

    // 저장 완료 콜백 호출
    widget.onSaved?.call();
  }

  /// 컨트롤러들을 정리하는 메서드
  void _cleanupControllers() {
    try {
      // 재생 중이면 중지
      if (_playerController?.playerState.isPlaying == true) {
        _playerController?.stopPlayer();
      }

      // 녹음 중이면 중지
      if (_recorderController.isRecording) {
        _recorderController.stop();
      }

      // 컨트롤러들 해제
      _playerController?.dispose();
      _playerController = null;
    } catch (e) {
      debugPrint('❌ 컨트롤러 정리 중 오류: $e');
    }
  }

  /// 프로필 이미지 드래그 UI (배치/저장 공통)
  Widget _buildProfileDraggable({required bool isPlacementMode}) {
    final profileWidget = Container(
      width: 54,
      height: 54,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child:
          widget.profileImageUrl != null && widget.profileImageUrl!.isNotEmpty
              ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: widget.profileImageUrl!,
                  width: 54,
                  height: 54,
                  memCacheWidth: (54 * 2).round(),
                  maxWidthDiskCache: (54 * 2).round(),
                  fit: BoxFit.cover,
                  placeholder: (context, url) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 14,
                      ),
                    );
                  },
                  errorWidget: (context, url, error) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.red[700],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error,
                        color: Colors.white,
                        size: 14,
                      ),
                    );
                  },
                ),
              )
              : Container(
                decoration: BoxDecoration(
                  color: Colors.orange[700],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 14),
              ),
    );

    if (widget.onProfileImageDragged == null) {
      return profileWidget;
    }

    return Draggable<String>(
      key: isPlacementMode ? _profileDraggableKey : null,
      data: 'profile_image',
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Transform.scale(
        scale: 1.2,
        child: Opacity(opacity: 0.8, child: profileWidget),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: profileWidget),
      onDragEnd: (details) {
        if (!isPlacementMode) {
          return;
        }

        if (details.wasAccepted) {
          _finalizePlacement();
        } else {
          _cancelPlacement();
        }
      },
      child: profileWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    // recording에서 recorded로 바뀔 때만 애니메이션 비활성화
    // recorded에서 saved로 바뀔 때는 애니메이션 활성화
    bool shouldAnimate =
        !(_lastState == VoiceCommentState.recording &&
            _currentState == VoiceCommentState.recorded);

    if (!shouldAnimate) {
      // 애니메이션 없이 즉시 전환 (recording → recorded만)
      return _buildCurrentStateWidget();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: _buildCurrentStateWidget(),
    );
  }

  /// 현재 상태에 맞는 위젯을 반환
  Widget _buildCurrentStateWidget() {
    // recording에서 recorded로 전환할 때 같은 키를 사용하여 애니메이션 방지
    String widgetKey;
    if (_lastState == VoiceCommentState.recording &&
        _currentState == VoiceCommentState.recorded) {
      widgetKey = 'audio-ui-no-animation';
    } else if (_currentState == VoiceCommentState.placing) {
      widgetKey = 'profile-placement';
    } else if (_currentState == VoiceCommentState.saved) {
      widgetKey = 'profile-mode';
    } else {
      widgetKey = _currentState.toString();
    }

    switch (_currentState) {
      case VoiceCommentState.idle:
        // comment.png 표시 (기존 feed_home.dart에서 처리)
        return Container(
          key: ValueKey(widgetKey),
          height: 52.h, // 녹음 UI와 동일한 높이
          alignment: Alignment.center, // 중앙 정렬
          child: const SizedBox.shrink(),
        );

      case VoiceCommentState.recording:
        return Selector<AudioController, String>(
          key: ValueKey(widgetKey),
          selector:
              (context, controller) => controller.formattedRecordingDuration,
          builder: (context, duration, child) {
            return _buildRecordingUI(duration);
          },
        );

      case VoiceCommentState.recorded:
        return Container(key: ValueKey(widgetKey), child: _buildPlaybackUI());

      case VoiceCommentState.placing:
        return Container(
          key: ValueKey(widgetKey),
          child: _buildProfileDraggable(isPlacementMode: true),
        );

      case VoiceCommentState.saved:
        return Container(
          key: ValueKey(widgetKey),
          child: _buildProfileDraggable(isPlacementMode: false),
        );
    }
  }
}
