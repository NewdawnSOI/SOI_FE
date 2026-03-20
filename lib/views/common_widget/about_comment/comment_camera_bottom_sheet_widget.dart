import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

import '../../../api/services/camera_service.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../utils/video_thumbnail_cache.dart';
import '../../about_camera/widgets/about_camera/camera_capture_button.dart';

class CommentCameraSheetResult {
  final String localFilePath;
  final bool isVideo;
  final int durationMs;

  const CommentCameraSheetResult({
    required this.localFilePath,
    required this.isVideo,
    required this.durationMs,
  });
}

enum _PendingVideoAction { none, stop, cancel }

class CommentCameraRecordingBottomSheetWidget extends StatefulWidget {
  /// 카메라 권한 요청, 사진 촬영, 최대 30초까지의 영상 촬영 기능을 제공하는 하단 시트 위젯입니다.
  const CommentCameraRecordingBottomSheetWidget({super.key});

  @override
  State<CommentCameraRecordingBottomSheetWidget> createState() =>
      _CommentCameraRecordingBottomSheetWidgetState();
}

class _CommentCameraRecordingBottomSheetWidgetState
    extends State<CommentCameraRecordingBottomSheetWidget> {
  static final double _sheetHeight = 360.sp;
  static final double _previewMaxSize = 181.sp;
  static const int _maxVideoDurationSeconds = 30;

  final CameraService _cameraService = CameraService.instance;
  final ValueNotifier<double> _videoProgress = ValueNotifier<double>(0.0);
  final ValueNotifier<int> _recordingDurationNotifier = ValueNotifier<int>(0);

  bool _isLoading = true;
  bool _isFlashOn = false;
  bool _isVideoRecording = false;
  bool _supportsLiveSwitch = false;
  bool _cameraSwitchInFlight = false;
  double _cameraSwitchTurns = 0.0;
  bool _videoStartInFlight = false;
  bool _videoStopInFlight = false;
  _PendingVideoAction _pendingVideoAction = _PendingVideoAction.none;

  String? _capturedPath;
  bool _capturedIsVideo = false;
  int _capturedDurationMs = 0;
  bool _showCapturedVideoPlayOverlay = true;
  bool _capturedVideoLoadFailed = false;
  VideoPlayerController? _capturedVideoController;
  Future<void>? _capturedVideoInitialization;

  DateTime? _recordingStartedAt;
  int _recordingDurationMs = 0;
  bool _confirmInFlight = false;

  Timer? _videoProgressTimer;
  StreamSubscription<String>? _videoRecordedSubscription;
  StreamSubscription<String>? _videoErrorSubscription;

  bool get _hasCapturedMedia => (_capturedPath ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    _setupVideoListeners();
    unawaited(_initializeCamera());
  }

  @override
  void dispose() {
    _videoRecordedSubscription?.cancel();
    _videoErrorSubscription?.cancel();
    _stopVideoProgressTimer();
    if (_isVideoRecording || _videoStartInFlight) {
      unawaited(_cameraService.cancelVideoRecording());
    }
    _videoStartInFlight = false;
    _videoStopInFlight = false;
    _pendingVideoAction = _PendingVideoAction.none;
    _disposeCapturedVideoController();
    unawaited(_cameraService.pauseCamera());
    _recordingDurationNotifier.dispose();
    _videoProgress.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final hasPermission = await _ensureCameraPermission();
    if (!hasPermission) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }

    await _cameraService.activateSession();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _supportsLiveSwitch = _cameraService.supportsLiveSwitch;
    });
  }

  Future<bool> _ensureCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isGranted) {
      return true;
    }
    status = await Permission.camera.request();
    return status.isGranted;
  }

  void _setupVideoListeners() {
    _videoRecordedSubscription = _cameraService.onVideoRecorded.listen((path) {
      if (!mounted || path.isEmpty) {
        return;
      }
      _videoStartInFlight = false;
      _videoStopInFlight = false;
      _pendingVideoAction = _PendingVideoAction.none;
      _applyCapturedResult(
        path: path,
        isVideo: true,
        durationMs: _recordingDurationMs,
      );
    });

    _videoErrorSubscription = _cameraService.onVideoError.listen((message) {
      if (!mounted) {
        return;
      }
      _stopVideoProgressTimer();
      setState(() {
        _isVideoRecording = false;
      });
      _videoStartInFlight = false;
      _videoStopInFlight = false;
      _pendingVideoAction = _PendingVideoAction.none;
      _showSnackBar(message);
    });
  }

  void _applyCapturedResult({
    required String path,
    required bool isVideo,
    required int durationMs,
  }) {
    if (!mounted || path.isEmpty) {
      return;
    }

    _stopVideoProgressTimer();
    setState(() {
      _isVideoRecording = false;
      _capturedPath = path;
      _capturedIsVideo = isVideo;
      _capturedDurationMs = durationMs;
      _recordingDurationMs = 0;
      _recordingStartedAt = null;
      _showCapturedVideoPlayOverlay = true;
      _capturedVideoLoadFailed = false;
    });
    _recordingDurationNotifier.value = 0;

    if (isVideo) {
      unawaited(_prepareCapturedVideoController(path));
    } else {
      _disposeCapturedVideoController();
    }
  }

  Future<void> _takePicture() async {
    if (_isLoading || _isVideoRecording || _hasCapturedMedia) {
      return;
    }

    final path = await _cameraService.takePicture();
    if (!mounted) {
      return;
    }

    if (path.isEmpty) {
      return;
    }

    _applyCapturedResult(path: path, isVideo: false, durationMs: 0);
  }

  Future<void> _startVideoRecording() async {
    if (_isLoading ||
        _isVideoRecording ||
        _videoStartInFlight ||
        _hasCapturedMedia) {
      return;
    }

    _videoStartInFlight = true;
    _recordingStartedAt = DateTime.now();
    _recordingDurationMs = 0;
    _recordingDurationNotifier.value = 0;
    final started = await _cameraService.startVideoRecording();

    if (!mounted) {
      _videoStartInFlight = false;
      return;
    }

    _videoStartInFlight = false;
    if (!started) {
      _pendingVideoAction = _PendingVideoAction.none;
      _showSnackBar(tr('camera.video_record_start_failed'));
      return;
    }

    setState(() {
      _isVideoRecording = true;
    });
    _startVideoProgressTimer();

    if (_pendingVideoAction != _PendingVideoAction.none) {
      final nextAction = _pendingVideoAction;
      _pendingVideoAction = _PendingVideoAction.none;
      if (nextAction == _PendingVideoAction.stop) {
        await _stopVideoRecording();
      } else if (nextAction == _PendingVideoAction.cancel) {
        await _cancelVideoRecording();
      }
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_videoStopInFlight) {
      return;
    }
    if (!_isVideoRecording) {
      if (_videoStartInFlight) {
        _pendingVideoAction = _PendingVideoAction.stop;
      }
      return;
    }

    _videoStopInFlight = true;
    final path = await _cameraService.stopVideoRecording();
    if (!mounted) {
      _videoStopInFlight = false;
      return;
    }
    _videoStopInFlight = false;

    if (path != null && path.isNotEmpty) {
      _applyCapturedResult(
        path: path,
        isVideo: true,
        durationMs: _recordingDurationMs,
      );
      return;
    }

    _stopVideoProgressTimer();
    setState(() {
      _isVideoRecording = false;
    });
    _pendingVideoAction = _PendingVideoAction.none;
  }

  Future<void> _cancelVideoRecording() async {
    if (_videoStopInFlight) {
      return;
    }
    if (!_isVideoRecording) {
      if (_videoStartInFlight) {
        _pendingVideoAction = _PendingVideoAction.cancel;
      }
      return;
    }

    _videoStopInFlight = true;
    await _cameraService.cancelVideoRecording();
    if (!mounted) {
      _videoStopInFlight = false;
      return;
    }
    _videoStopInFlight = false;
    _stopVideoProgressTimer();
    setState(() {
      _isVideoRecording = false;
    });
    _pendingVideoAction = _PendingVideoAction.none;
  }

  void _startVideoProgressTimer() {
    _videoProgress.value = 0.0;
    _videoProgressTimer?.cancel();
    _videoProgressTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (!mounted || !_isVideoRecording) {
        timer.cancel();
        return;
      }

      final startedAt = _recordingStartedAt;
      if (startedAt != null) {
        _recordingDurationMs = DateTime.now()
            .difference(startedAt)
            .inMilliseconds;
        _recordingDurationNotifier.value = _recordingDurationMs;
      }

      final next = _videoProgress.value + (0.1 / _maxVideoDurationSeconds);
      if (next >= 1.0) {
        _videoProgress.value = 1.0;
        timer.cancel();
        unawaited(_stopVideoRecording());
        return;
      }
      _videoProgress.value = next;
    });
  }

  void _stopVideoProgressTimer() {
    _videoProgressTimer?.cancel();
    _videoProgressTimer = null;
    _videoProgress.value = 0.0;
    _recordingDurationNotifier.value = _recordingDurationMs;
  }

  Future<void> _toggleFlash() async {
    if (_isLoading) {
      return;
    }
    final newFlashState = !_isFlashOn;
    await _cameraService.setFlash(newFlashState);
    if (!mounted) {
      return;
    }
    setState(() {
      _isFlashOn = newFlashState;
    });
  }

  Future<void> _onSwitchCameraPressed() async {
    if (_cameraSwitchInFlight || _isLoading || _videoStartInFlight) {
      return;
    }
    if (_isVideoRecording && !_supportsLiveSwitch) {
      _showSnackBar(tr('camera.switch_not_supported_while_recording'));
      return;
    }

    setState(() {
      _cameraSwitchInFlight = true;
      _cameraSwitchTurns += 1;
    });

    try {
      await _cameraService.switchCamera();
    } finally {
      if (mounted) {
        setState(() {
          _cameraSwitchInFlight = false;
        });
      }
    }
  }

  void _resetCapturedState() {
    _disposeCapturedVideoController();
    if (!mounted) {
      return;
    }
    setState(() {
      _capturedPath = null;
      _capturedIsVideo = false;
      _capturedDurationMs = 0;
      _showCapturedVideoPlayOverlay = true;
      _capturedVideoLoadFailed = false;
    });
  }

  Future<void> _closeSheet() async {
    if (_isVideoRecording ||
        _videoStartInFlight ||
        _pendingVideoAction != _PendingVideoAction.none) {
      await _cancelVideoRecording();
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _confirmCaptured() async {
    if (_confirmInFlight) {
      return;
    }
    final path = _capturedPath;
    if (path == null || path.isEmpty) {
      return;
    }

    _confirmInFlight = true;
    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(
      CommentCameraSheetResult(
        localFilePath: path,
        isVideo: _capturedIsVideo,
        durationMs: _capturedIsVideo ? _capturedDurationMs : 0,
      ),
    );
  }

  void _disposeCapturedVideoController() {
    _capturedVideoController?.pause();
    _capturedVideoController?.dispose();
    _capturedVideoController = null;
    _capturedVideoInitialization = null;
  }

  Future<void> _prepareCapturedVideoController(String path) async {
    _disposeCapturedVideoController();

    final file = File(path);
    if (!await file.exists()) {
      if (!mounted) return;
      setState(() {
        _capturedVideoLoadFailed = true;
      });
      return;
    }

    final controller = VideoPlayerController.file(file);
    _capturedVideoController = controller;
    _capturedVideoInitialization = controller
        .initialize()
        .then((_) async {
          await controller.setLooping(true);
          await controller.setVolume(1.0); // 영상의 음량을 최대치로 설정
          if (!mounted) return;
          setState(() {
            _capturedVideoLoadFailed = false;
            _showCapturedVideoPlayOverlay = true;
          });
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() {
            _capturedVideoLoadFailed = true;
          });
        });

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _toggleCapturedVideoPlayback() async {
    final controller = _capturedVideoController;
    final initialization = _capturedVideoInitialization;
    if (controller == null || initialization == null) {
      return;
    }

    try {
      if (!controller.value.isInitialized) {
        await initialization;
      }
      if (!mounted || !controller.value.isInitialized) {
        return;
      }

      if (controller.value.isPlaying) {
        await controller.pause();
        if (!mounted) return;
        setState(() {
          _showCapturedVideoPlayOverlay = true;
        });
      } else {
        await controller.play();
        if (!mounted) return;
        setState(() {
          _showCapturedVideoPlayOverlay = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _capturedVideoLoadFailed = true;
      });
    }
  }

  /// 바텀 시트 상단 위젯
  /// 캡처된 미디어가 없는 경우에는 닫기 버튼만 표시되고,
  /// 캡처된 미디어가 있는 경우에는 뒤로 가기 버튼과 확인 버튼이 표시됩니다.
  Widget _buildTopBar() {
    if (_hasCapturedMedia) {
      return Row(
        children: [
          Padding(
            padding: EdgeInsets.only(left: (7.96).sp, top: (7.96).sp),
            child: IconButton(
              onPressed: _resetCapturedState,
              icon: Icon(Icons.chevron_left, color: Colors.white, size: 40.sp),
            ),
          ),
          const Spacer(),

          Padding(
            padding: EdgeInsets.only(right: (15.96).sp, top: (7.96).sp),
            child: SizedBox(
              height: 29.sp,
              child: TextButton(
                onPressed: _confirmCaptured,
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

    // 캡처된 미디어가 없는 경우에는 닫기 버튼만 표시
    return Row(
      children: [
        Padding(
          padding: EdgeInsets.only(top: (7.96).sp),
          child: IconButton(
            onPressed: _closeSheet,
            icon: SvgPicture.asset(
              "assets/cancel.svg",
              width: (30.08).sp,
              height: (30.08).sp,
            ),
          ),
        ),
      ],
    );
  }

  /// 사진/영상 프리뷰 위젯
  Widget _buildPreviewWidget() {
    final path = _capturedPath;
    if (_isLoading) {
      return Container(
        width: _previewMaxSize.sp,
        height: _previewMaxSize.sp,
        decoration: const BoxDecoration(
          color: Color(0xFF505050),
          shape: BoxShape.circle,
        ),
        clipBehavior: Clip.antiAlias,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (path != null && path.isNotEmpty) {
      if (_capturedIsVideo) {
        final controller = _capturedVideoController;
        final initialization = _capturedVideoInitialization;
        final canUsePlayer =
            !_capturedVideoLoadFailed &&
            controller != null &&
            initialization != null;

        return Container(
          width: _previewMaxSize.sp,
          height: _previewMaxSize.sp,
          decoration: const BoxDecoration(
            color: Color(0xFF505050),
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleCapturedVideoPlayback,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 영상이 정상적으로 로드된 경우에는 VideoPlayer 위젯을 사용하여 프리뷰를 보여주고,
                if (canUsePlayer)
                  FutureBuilder<void>(
                    future: initialization,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done ||
                          !controller.value.isInitialized) {
                        return FutureBuilder<Uint8List?>(
                          future: VideoThumbnailCache.getThumbnail(
                            videoUrl: path,
                            cacheKey: path,
                          ),
                          builder: (context, snapshot) {
                            final bytes = snapshot.data;
                            if (bytes != null) {
                              return Image.memory(bytes, fit: BoxFit.cover);
                            }
                            return const ColoredBox(color: Color(0xFF5A5A5A));
                          },
                        );
                      }

                      final width = controller.value.size.width;
                      final height = controller.value.size.height;
                      if (width <= 0 || height <= 0) {
                        return FutureBuilder<Uint8List?>(
                          future: VideoThumbnailCache.getThumbnail(
                            videoUrl: path,
                            cacheKey: path,
                          ),
                          builder: (context, snapshot) {
                            final bytes = snapshot.data;
                            if (bytes != null) {
                              return Image.memory(bytes, fit: BoxFit.cover);
                            }
                            return const ColoredBox(color: Color(0xFF5A5A5A));
                          },
                        );
                      }

                      return FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: width,
                          height: height,
                          child: VideoPlayer(controller),
                        ),
                      );
                    },
                  )
                // 영상이 로드되지 않았거나 초기화되지 않은 경우에는 썸네일 이미지 보여주기
                else
                  FutureBuilder<Uint8List?>(
                    future: VideoThumbnailCache.getThumbnail(
                      videoUrl: path,
                      cacheKey: path,
                    ),
                    builder: (context, snapshot) {
                      final bytes = snapshot.data;
                      if (bytes != null) {
                        return Image.memory(bytes, fit: BoxFit.cover);
                      }
                      return const ColoredBox(color: Color(0xFF5A5A5A));
                    },
                  ),
                if (_showCapturedVideoPlayOverlay)
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
              ],
            ),
          ),
        );
      }

      final file = File(path);
      return Container(
        width: _previewMaxSize.sp,
        height: _previewMaxSize.sp,
        decoration: const BoxDecoration(
          color: Color(0xFF505050),
          shape: BoxShape.circle,
        ),
        clipBehavior: Clip.antiAlias,
        child: !file.existsSync()
            ? const Center(
                child: Icon(
                  Icons.image_not_supported,
                  color: Colors.white70,
                  size: 34,
                ),
              )
            : Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white70,
                      size: 34,
                    ),
                  );
                },
              ),
      );
    }

    return Container(
      width: _previewMaxSize.sp,
      height: _previewMaxSize.sp,
      decoration: const BoxDecoration(
        color: Color(0xFF505050),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipOval(
        child: SizedBox.expand(child: _cameraService.buildCameraView()),
      ),
    );
  }

  /// 하단 플래시, 촬영, 토글 Row 위젯
  Widget _buildBottomControlsRow() {
    if (_hasCapturedMedia) {
      return const SizedBox(height: 56);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 플래시 토글 버튼
        SizedBox(
          width: 120.sp,
          child: IconButton(
            onPressed: _toggleFlash,
            icon: Icon(
              _isFlashOn ? EvaIcons.flash : EvaIcons.flashOff,
              color: Colors.white,
              size: 34.sp,
            ),
          ),
        ),
        CameraCaptureButton(
          isVideoRecording: _isVideoRecording,
          videoProgress: _videoProgress,
          onTakePicture: _takePicture,
          onStartVideoRecording: _startVideoRecording,
          onStopVideoRecording: _stopVideoRecording,
        ),
        SizedBox(
          width: 120.sp,
          child: IconButton(
            onPressed:
                (_isVideoRecording && !_supportsLiveSwitch) ||
                    _cameraSwitchInFlight
                ? null
                : _onSwitchCameraPressed,
            icon: AnimatedRotation(
              turns: _cameraSwitchTurns,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOut,
              child: Image.asset(
                'assets/switch.png',
                width: 52.sp,
                height: 52.sp,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    SnackBarUtils.showSnackBar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: _sheetHeight,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFF1F1F1F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: _previewMaxSize,
                            maxHeight: _previewMaxSize,
                          ),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: _buildPreviewWidget(),
                          ),
                        ),
                      ),
                    ),

                    if (_isVideoRecording)
                      ValueListenableBuilder<int>(
                        valueListenable: _recordingDurationNotifier,
                        builder: (_, durationMs, __) {
                          return Text(
                            _formatDuration(Duration(milliseconds: durationMs)),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.sp,
                              fontFamily: 'Pretendard Variable',
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      )
                    else if (_hasCapturedMedia && _capturedIsVideo)
                      Text(
                        _formatDuration(
                          Duration(milliseconds: _capturedDurationMs),
                        ),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontFamily: 'Pretendard Variable',
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      SizedBox(height: 20.sp),
                    SizedBox(height: 20.sp),

                    // 하단 플래시, 촬영, 토글 Row 위젯
                    SizedBox(
                      height: 65,
                      child: Align(
                        alignment: Alignment.center,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: 56,
                            maxHeight: 65,
                          ),
                          child: _buildBottomControlsRow(),
                        ),
                      ),
                    ),
                    SizedBox(height: 32.sp),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
