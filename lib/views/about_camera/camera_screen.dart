import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import '../../services/camera_service.dart';
import '../../controllers/notification_controller.dart';
import '../../controllers/auth_controller.dart';
import 'widgets/circular_video_progress_indicator.dart';
import 'photo_editor_screen.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:photo_manager/photo_manager.dart';

enum _PendingVideoAction { none, stop, cancel }

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  // Swift와 통신할 플랫폼 채널
  final CameraService _cameraService = CameraService();

  // 추가: 카메라 관련 상태 변수
  // 촬영된 이미지 경로
  String imagePath = '';

  // 플래시 상태 추적
  bool isFlashOn = false;

  // 추가: 줌 레벨 관리
  // 기본 줌 레벨
  String currentZoom = '1x';
  double currentZoomValue = 1.0;

  // 동적 줌 레벨 (디바이스별로 결정됨)
  List<Map<String, dynamic>> zoomLevels = [
    {'label': '1x', 'value': 1.0}, // 기본값
  ];

  // 카메라 초기화 Future 추가
  Future<void>? _cameraInitialization;
  bool _isInitialized = false;

  // 카메라 로딩 중 상태
  bool _isLoading = true;

  // 갤러리 미리보기 상태 관리
  AssetEntity? _firstGalleryImage;
  bool _isLoadingGallery = false;
  String? _galleryError;

  // 비디오 녹화 상태 관리
  bool _isVideoRecording = false;

  // 비디오 녹화 후 처리
  StreamSubscription<String>? _videoRecordedSubscription;

  // 비디오 녹화 오류 처리
  StreamSubscription<String>? _videoErrorSubscription;

  // 비디오 녹화 중 상태 관리
  _PendingVideoAction _pendingVideoAction = _PendingVideoAction.none;

  // 비디오 녹화 중 상태 관리
  bool _videoStartInFlight = false;

  // 비디오 녹화 Progress 관리
  Timer? _videoProgressTimer;

  // 0.0 ~ 1.0을 기준으로 두고, 30초로 나누어 증가시킴
  // ValueNotifier로 변경하여 Progress 업데이트 시 전체 위젯 리빌드 방지
  final ValueNotifier<double> _videoProgress = ValueNotifier<double>(0.0);

  // 최대 녹화 시간 --> 30초
  static const int _maxVideoDurationSeconds = 30;

  // IndexedStack에서 상태 유지
  @override
  bool get wantKeepAlive => true;

  // 개선: 지연 초기화로 성능 향상
  @override
  void initState() {
    super.initState();

    _setupVideoListeners();

    // 앱 라이프사이클 옵저버 등록
    WidgetsBinding.instance.addObserver(this);

    // 카메라 초기화를 지연시킴 (첫 빌드에서 UI 블로킹 방지)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // FutureBuilder 연동을 위해 Future 보관
      _cameraInitialization = _initializeCameraAsync();

      // 알림 초기화는 전환에 영향 없도록 지연 실행
      // microtask로 실행하여 다른 작업과 상관없이 실행되도록 한다.
      Future.microtask(_initializeNotifications);
    });
  }

  // 비동기 카메라 초기화
  Future<void> _initializeCameraAsync() async {
    if (!_isInitialized && mounted) {
      try {
        // 세션만 우선 활성화하여 화면을 즉시 표시
        await _cameraService.activateSession();

        if (mounted) {
          setState(() {
            _isLoading = false;
            _isInitialized = true;
          });
        }

        // 갤러리 첫 이미지를 microtask로 가져온다.
        // 다른 작업과 상관없이 실행되도록 한다.
        Future.microtask(() => _loadFirstGalleryImage());

        // 디바이스별 사용 가능한 줌 레벨을 가져온다.
        Future.microtask(() => _loadAvailableZoomLevels());
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // 디바이스별 사용 가능한 줌 레벨 로드
  Future<void> _loadAvailableZoomLevels() async {
    try {
      final availableLevels = await _cameraService.getAvailableZoomLevels();

      if (mounted) {
        setState(() {
          zoomLevels =
              availableLevels.map((level) {
                if (level == 0.5) {
                  return {'label': '.5x', 'value': level};
                } else if (level == 1.0) {
                  return {'label': '1x', 'value': level};
                } else if (level == 2.0) {
                  return {'label': '2x', 'value': level};
                } else if (level == 3.0) {
                  return {'label': '3x', 'value': level};
                } else {
                  return {
                    'label': '${level.toStringAsFixed(1)}x',
                    'value': level,
                  };
                }
              }).toList();
        });
      }
    } catch (e) {
      // 줌 레벨 로드 실패 시 기본값 유지
      debugPrint('❌ 줌 레벨 로드 실패: $e');
    }
  }

  // 알림 초기화 - 사용자 ID로 알림 구독 시작
  Future<void> _initializeNotifications() async {
    try {
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final notificationController = Provider.of<NotificationController>(
        context,
        listen: false,
      );

      final userId = authController.getUserId;
      if (userId != null && userId.isNotEmpty) {
        await notificationController.startListening(userId);
      }
    } catch (e) {
      debugPrint('❌ CameraScreen: 알림 초기화 실패 - $e');
    }
  }

  // 비디오 녹화 이벤트 리스너 설정
  /// 이 코드는 비디오 녹화 기능을 위한 이벤트 리스너를 정의합니다.
  /// 카메라 화면 내에서 비디오 녹화 프로세스의 시작, 중지 또는 관리를
  /// 관련된 특정 이벤트를 수신 대기합니다. 이 리스너는 사용자 상호작용이나
  /// 시스템 트리거와 관련된 비디오 녹화를 효과적으로 처리할 수 있도록 보장합니다.
  void _setupVideoListeners() {
    // 비디오 녹화 시에 처리
    _videoRecordedSubscription = _cameraService.onVideoRecorded.listen((
      String path,
    ) {
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();

      setState(() {
        _isVideoRecording = false;
      });
      _videoStartInFlight = false;
      _pendingVideoAction = _PendingVideoAction.none;

      if (path.isNotEmpty) {
        // 동영상 저장 후 처리
        Future.microtask(() => _cameraService.refreshGalleryPreview());

        messenger.showSnackBar(
          SnackBar(
            content: const Text('동영상이 저장되었습니다.'),
            backgroundColor: const Color(0xFF5A5A5A),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });

    // 비디오 녹화 오류시에 처리
    _videoErrorSubscription = _cameraService.onVideoError.listen((
      String message,
    ) {
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();

      setState(() {
        _isVideoRecording = false;
      });
      _videoStartInFlight = false;
      _pendingVideoAction = _PendingVideoAction.none;

      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFD9534F),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  // 개선된 갤러리 첫 번째 이미지 로딩
  Future<void> _loadFirstGalleryImage() async {
    // 비디오 녹화 중에는 갤러리 이미지 로드하지 않음
    if (_isLoadingGallery || _isVideoRecording) return;

    setState(() {
      _isLoadingGallery = true;
      _galleryError = null;
    });

    try {
      final AssetEntity? firstImage =
          await _cameraService.getFirstGalleryImage();

      if (mounted) {
        setState(() {
          _firstGalleryImage = firstImage;
          _isLoadingGallery = false;
        });
      }
    } catch (e) {
      // Gallery image loading failed with error: $e
      if (mounted) {
        setState(() {
          _galleryError = '갤러리 접근 실패';
          _isLoadingGallery = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // 앱 라이프사이클 옵저버 해제
    WidgetsBinding.instance.removeObserver(this);

    _videoRecordedSubscription?.cancel();
    _videoErrorSubscription?.cancel();

    // Progress 타이머 정리
    _videoProgressTimer?.cancel();
    _videoProgress.dispose();

    if (_isVideoRecording) {
      unawaited(_cameraService.cancelVideoRecording());
    }
    _videoStartInFlight = false;
    _pendingVideoAction = _PendingVideoAction.none;

    PaintingBinding.instance.imageCache.clear();

    super.dispose();
  }

  // 앱 라이프사이클 상태 변화 감지
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 다시 활성화될 때 카메라 세션 복구
    if (state == AppLifecycleState.resumed) {
      if (_isInitialized) {
        _cameraService.resumeCamera();

        // 갤러리 미리보기 새로고침 (다른 앱에서 사진을 찍었을 수 있음)
        _loadFirstGalleryImage();
      }
    }
    // 앱이 완전히 백그라운드로 갈 때만 비디오 녹화 중지
    // inactive는 일시적 상태이므로 무시 (알림 센터, 화면 전환 등)
    else if (state == AppLifecycleState.paused) {
      // paused: 앱이 완전히 백그라운드로 갔을 때만 녹화 중지
      if (_isVideoRecording ||
          _videoStartInFlight ||
          _pendingVideoAction != _PendingVideoAction.none) {
        unawaited(_stopVideoRecording(isCancelled: true));
      }
      _cameraService.pauseCamera();
    }
    // inactive 상태에서는 카메라만 일시 정지 (비디오 녹화는 유지)
    else if (state == AppLifecycleState.inactive) {
      // inactive: 일시적 비활성화 (알림, 전화 등)
      // 비디오 녹화는 중지하지 않고 카메라만 일시 정지
      if (!_isVideoRecording) {
        _cameraService.pauseCamera();
      }
    }
  }

  // cameraservice에 플래시 토글 요청
  Future<void> _toggleFlash() async {
    try {
      final bool newFlashState = !isFlashOn;
      await _cameraService.setFlash(newFlashState);

      setState(() {
        isFlashOn = newFlashState;
      });
    } on PlatformException {
      // Flash toggle error occurred: ${e.message}
    }
  }

  // cameraservice에 사진 촬영 요청
  Future<void> _takePicture() async {
    try {
      // iOS에서 오디오 세션 충돌 방지를 위한 사전 처리
      if (Theme.of(context).platform == TargetPlatform.iOS) {
        // iOS 플랫폼에서만 실행 - 잠시 대기하여 오디오 세션 정리
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final String result = await _cameraService.takePicture();
      setState(() {
        imagePath = result;
      });

      // 사진 촬영 후 처리
      if (result.isNotEmpty && mounted) {
        // 즉시 편집 화면으로 이동 (갤러리 새로고침과 독립적)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoEditorScreen(imagePath: result),
          ),
        );
        // 사진 촬영 후 갤러리 미리보기 새로고침 (백그라운드에서)
        Future.microtask(() => _loadFirstGalleryImage());
      }
    } on PlatformException catch (e) {
      // Picture taking error occurred: ${e.message}

      // iOS에서 "Cannot Record" 오류가 발생한 경우 추가 정보 제공
      if (e.message?.contains("Cannot Record") == true) {
        // iOS audio session conflict detected - possible audio recording in progress
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('카메라 촬영 중 오류가 발생했습니다. 오디오 녹음을 중지하고 다시 시도해주세요.'),
              backgroundColor: Color(0xFF5A5A5A),
            ),
          );
        }
      }
    } catch (e) {
      // 추가 예외 처리
      // Unexpected error occurred during picture taking: $e
    }
  }

  Future<void> _startVideoRecording() async {
    if (_isVideoRecording) {
      return;
    }

    _videoStartInFlight = true;
    final bool started = await _cameraService.startVideoRecording();
    if (!mounted) {
      _videoStartInFlight = false;
      return;
    }

    _videoStartInFlight = false;
    if (started) {
      setState(() {
        _isVideoRecording = true;
      });

      // Progress 타이머 시작
      _startVideoProgressTimer();

      if (_pendingVideoAction != _PendingVideoAction.none) {
        final nextAction = _pendingVideoAction;
        _pendingVideoAction = _PendingVideoAction.none;

        if (nextAction == _PendingVideoAction.stop) {
          await _stopVideoRecording();
        } else if (nextAction == _PendingVideoAction.cancel) {
          await _stopVideoRecording(isCancelled: true);
        }
      }
    } else {
      setState(() {
        _isVideoRecording = false;
      });
      _pendingVideoAction = _PendingVideoAction.none;

      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('동영상 녹화를 시작할 수 없습니다.'),
          backgroundColor: Color(0xFFD9534F),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _stopVideoRecording({bool isCancelled = false}) async {
    if (!_isVideoRecording) {
      if (!_videoStartInFlight) {
        return;
      }
      _pendingVideoAction =
          isCancelled ? _PendingVideoAction.cancel : _PendingVideoAction.stop;
      return;
    }

    if (isCancelled) {
      await _cameraService.cancelVideoRecording();
    } else {
      await _cameraService.stopVideoRecording();
    }

    if (!mounted) return;
    setState(() {
      _isVideoRecording = false;
    });
    _pendingVideoAction = _PendingVideoAction.none;

    // Progress 타이머 중지
    _stopVideoProgressTimer();
  }

  /// 비디오 녹화 Progress 타이머 시작
  void _startVideoProgressTimer() {
    _videoProgress.value = 0.0;
    _videoProgressTimer?.cancel();

    _videoProgressTimer = Timer.periodic(
      const Duration(milliseconds: 100), // 0.1초마다 업데이트
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        // ValueNotifier 사용으로 전체 위젯 리빌드 방지
        _videoProgress.value += 0.1 / _maxVideoDurationSeconds;

        // 30초 도달 시 자동으로 녹화 중지
        if (_videoProgress.value >= 1.0) {
          _videoProgress.value = 1.0;
          _stopVideoProgressTimer();
          // 자동 중지는 Swift 플러그인에서 처리됨
        }
      },
    );
  }

  /// 비디오 녹화 Progress 타이머 중지
  void _stopVideoProgressTimer() {
    _videoProgressTimer?.cancel();
    _videoProgressTimer = null;
    _videoProgress.value = 0.0;
  }

  /// 갤러리 콘텐츠 빌드 (로딩/에러/이미지 상태 처리)
  Widget _buildGalleryContent(double gallerySize, double borderRadius) {
    // 로딩 중 - shimmer 효과 적용
    if (_isLoadingGallery) {
      return Shimmer.fromColors(
        baseColor: Colors.grey.shade800,
        highlightColor: Colors.grey.shade700,
        period: const Duration(milliseconds: 1500),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            width: 46.w,
            height: 46.h,
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.0,
              ),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        ),
      );
    }

    // 에러 상태
    if (_galleryError != null) {
      return _buildPlaceholderGallery(46);
    }

    // 갤러리 이미지 표시
    if (_firstGalleryImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: FutureBuilder<Uint8List?>(
          future: _firstGalleryImage!.thumbnailData,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return Image.memory(
                snapshot.data!,
                width: 46.w,
                height: 46.h,

                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Gallery thumbnail memory load error: $error
                  return _buildPlaceholderGallery(gallerySize);
                },
              );
            } else if (snapshot.hasError) {
              // Gallery thumbnail data load error: ${snapshot.error}
              return _buildPlaceholderGallery(gallerySize);
            } else {
              return Shimmer.fromColors(
                baseColor: Colors.grey.shade800,
                highlightColor: Colors.grey.shade700,
                period: const Duration(milliseconds: 1500),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: Container(
                    width: 46.w,
                    height: 46.h,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1.0,
                      ),
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                  ),
                ),
              );
            }
          },
        ),
      );
    }

    // 기본 플레이스홀더
    return _buildPlaceholderGallery(gallerySize);
  }

  /// 갤러리 플레이스홀더 위젯 - 반응형
  Widget _buildPlaceholderGallery(double gallerySize) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade800,
      highlightColor: Colors.grey.shade700,
      period: const Duration(milliseconds: 1500),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Container(
          width: gallerySize,
          height: gallerySize,
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      ),
    );
  }

  // cameraservice에 카메라 전환 요청
  Future<void> _switchCamera() async {
    try {
      await _cameraService.switchCamera();

      // 카메라 전환 후 줌 레벨 다시 로드 (전면/후면 카메라별 지원 줌이 다름)
      await _loadAvailableZoomLevels();

      // 현재 줌이 새 카메라에서 지원되지 않으면 1x로 리셋
      final supportedValues =
          zoomLevels.map((z) => z['value'] as double).toList();
      if (!supportedValues.contains(currentZoomValue)) {
        setState(() {
          currentZoomValue = 1.0;
          currentZoom = '1x';
        });
      }
    } on PlatformException {
      // Camera switching error occurred: ${e.message}
    }
  }

  // 녹화 상태를 표시하는 위젯
  Widget _buildRecordingIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10.w,
            height: 10.w,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            'REC',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14.sp,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // 줌 레벨 변경 요청
  Future<void> _setZoomLevel(double zoomValue, String zoomLabel) async {
    try {
      await _cameraService.setZoom(zoomValue);
      setState(() {
        currentZoomValue = zoomValue;
        currentZoom = zoomLabel;
      });
    } on PlatformException catch (e) {
      // Zoom setting error occurred: ${e.message}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('줌 설정 중 오류가 발생했습니다: ${e.message}'),
            backgroundColor: const Color(0xFF5A5A5A),
          ),
        );
      }
    }
  }

  // 줌 컨트롤 위젯 빌드
  Widget _buildZoomControls() {
    return Container(
      width: 147.w,
      height: 50.h,
      decoration: BoxDecoration(
        color: Color(0xff000000).withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < zoomLevels.length; i++) ...[
            // 고정된 크기의 컨테이너로 레이아웃 안정화
            SizedBox(
              width: 45.w, // 최대 크기로 고정
              height: 45.h, // 최대 크기로 고정
              child: GestureDetector(
                onTap:
                    () => _setZoomLevel(
                      zoomLevels[i]['value'],
                      zoomLevels[i]['label'],
                    ),
                child: Center(
                  child: Container(
                    width:
                        zoomLevels[i]['value'] == currentZoomValue
                            ? 45.w
                            : 29.w,
                    height:
                        zoomLevels[i]['value'] == currentZoomValue
                            ? 45.h
                            : 29.h,
                    decoration: BoxDecoration(
                      color: Color(0xff2c2c2c),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        zoomLevels[i]['label'],
                        style: TextStyle(
                          color:
                              zoomLevels[i]['value'] == currentZoomValue
                                  ? Colors.yellow
                                  : Color(0xffffffff),
                          fontSize:
                              zoomLevels[i]['value'] == currentZoomValue
                                  ? (14.36).sp
                                  : (12.36).sp,
                          fontWeight:
                              zoomLevels[i]['value'] == currentZoomValue
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                          fontFamily: 'Pretendard Variable',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Color(0xff000000),

      appBar: AppBar(
        leadingWidth: 90.w,
        title: Column(
          children: [
            Text(
              'SOI',
              style: TextStyle(
                color: Color(0xfff9f9f9),
                fontSize: 20.sp,
                fontFamily: GoogleFonts.inter().fontFamily,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 30.h),
          ],
        ),
        backgroundColor: Colors.black,
        toolbarHeight: 70.h,
        leading: Row(
          children: [
            SizedBox(width: 32.w),
            IconButton(
              constraints: BoxConstraints(),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pushNamed(context, '/contact_manager'),
              icon: Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: Color(0xff1c1c1c),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.people, color: Colors.white, size: 25.sp),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 32.w),
            child: Center(
              child: Consumer<NotificationController>(
                builder: (context, notificationController, child) {
                  return IconButton(
                    onPressed:
                        () => Navigator.pushNamed(context, '/notifications'),
                    icon: Container(
                      width: 35,
                      height: 35,
                      padding: EdgeInsets.only(bottom: 3.h),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Color(0xff1c1c1c),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(top: 2.h),
                        child: Image.asset(
                          "assets/notification.png",
                          width: 25.sp,
                          height: 25.sp,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Center(
              child: FutureBuilder<void>(
                future: _cameraInitialization,
                builder: (context, snapshot) {
                  if (_isLoading) {
                    return Shimmer.fromColors(
                      baseColor: Colors.grey.shade800,
                      highlightColor: Colors.grey.shade700,
                      period: const Duration(milliseconds: 1500),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 354.w,
                          height: 500.h,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800,

                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    );
                  }

                  // 초기화 실패 시 오류 메시지 표시
                  if (snapshot.hasError) {
                    return Container(
                      constraints: BoxConstraints(maxHeight: double.infinity),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          '카메라를 시작할 수 없습니다.\n앱을 다시 시작해 주세요.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18.sp,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  // 카메라 초기화 완료되면 카메라 뷰 표시
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 354.w,
                          height: 500.h,

                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              // 카메라 뷰
                              _cameraService.getCameraView(),

                              // 줌 컨트롤 (줌 레벨이 있을 때만 표시)
                              if (zoomLevels.isNotEmpty && !_isVideoRecording)
                                Padding(
                                  padding: EdgeInsets.only(bottom: 26.h),
                                  child: _buildZoomControls(),
                                ),
                            ],
                          ),
                        ),
                      ),

                      if (_isVideoRecording)
                        Positioned(
                          top: 12.h,
                          child: _buildRecordingIndicator(),
                        ),

                      // 플래시 버튼
                      (_isVideoRecording)
                          ? SizedBox()
                          : IconButton(
                            onPressed: _toggleFlash,
                            icon: Icon(
                              isFlashOn ? EvaIcons.flash : EvaIcons.flashOff,
                              color: Colors.white,
                              size: 28.sp,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                    ],
                  );
                },
              ),
            ),
            SizedBox(height: 20.h),
            // 수정: 하단 버튼 레이아웃 변경 - 반응형
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 갤러리 미리보기 버튼 (Service 상태 사용) - 반응형
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: InkWell(
                      onTap: () async {
                        try {
                          // Service를 통해 갤러리에서 이미지 선택 (에러 핸들링 개선)
                          final result =
                              await _cameraService.pickImageFromGallery();
                          if (result != null && result.isNotEmpty && mounted) {
                            // 선택한 이미지 경로를 편집 화면으로 전달
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        PhotoEditorScreen(imagePath: result),
                              ),
                            );
                          } else {
                            // No image was selected from gallery
                          }
                        } catch (e) {
                          // Error occurred while selecting image from gallery: $e
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('갤러리에서 이미지를 선택할 수 없습니다'),
                                backgroundColor: const Color(0xFF5A5A5A),
                              ),
                            );
                          }
                        }
                      },
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.76),
                        ),
                        child: _buildGalleryContent(46, 8.76),
                      ),
                    ),
                  ),
                ),

                // 촬영 버튼 및 비디오 녹화 제스처
                SizedBox(
                  width: 90.w,
                  child: Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _takePicture,
                      onLongPress: () async {
                        await _startVideoRecording();
                      },

                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            height: 90.h,
                            child:
                                // 비디오 녹화 모드가 ON이 되면, 진행률 표시기로 전환
                                (_isVideoRecording)
                                    ? ValueListenableBuilder<double>(
                                      valueListenable: _videoProgress,
                                      builder: (context, progress, child) {
                                        return GestureDetector(
                                          onTap: () => _stopVideoRecording(),
                                          child: CircularVideoProgressIndicator(
                                            progress: progress,
                                            innerSize: 40.42,
                                            gap: 15.29,
                                            strokeWidth: 3.0,
                                          ),
                                        );
                                      },
                                    )
                                    : Image.asset(
                                      "assets/take_picture.png",
                                      width: 65,
                                      height: 65,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 카메라 전환 버튼 - 개선된 반응형
                Expanded(
                  child: IconButton(
                    onPressed: _switchCamera,
                    color: Color(0xffd9d9d9),
                    icon: Image.asset(
                      "assets/switch.png",
                      width: 67.w,
                      height: 56.h,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 30.h),
          ],
        ),
      ),
    );
  }
}
