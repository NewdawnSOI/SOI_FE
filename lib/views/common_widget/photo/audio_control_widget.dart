import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/media_controller.dart';

import '../../../api/models/post.dart';
import '../../../api/controller/audio_controller.dart';
import '../../about_archiving/widgets/wave_form_widget/custom_waveform_widget.dart';

/// API 기반 오디오 컨트롤 위젯
///
/// post의 audioUrl이 null이 아니면 재생 가능
///
/// Parameters:
///   - [post]: 오디오가 포함된 Post 객체 (필수)
///   - [waveformData]: 오디오 파형 데이터 (선택적)
///   - [onPressed]: 커스텀 재생/일시정지 콜백 (선택적)
class ApiAudioControlWidget extends StatefulWidget {
  final Post post;
  final List<double>? waveformData;
  final VoidCallback? onPressed;

  const ApiAudioControlWidget({
    super.key,
    required this.post,
    this.waveformData,
    this.onPressed,
  });

  @override
  State<ApiAudioControlWidget> createState() => _ApiAudioControlWidgetState();
}

class _ApiAudioControlWidgetState extends State<ApiAudioControlWidget> {
  String? _profileImageUrl;
  bool _isProfileLoading = false;
  int _profileLoadGeneration = 0;
  String? _audioUrl;
  bool _isAudioLoading = false;

  @override
  void initState() {
    super.initState();
    _profileImageUrl = _resolveImmediateProfileImageUrl();
    _isProfileLoading =
        _profileImageUrl == null && _normalizedProfileImageKey() != null;
    _fetchProfileImage();
    _fetchAudioUrl(widget.post.audioUrl);
  }

  @override
  void didUpdateWidget(covariant ApiAudioControlWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.userProfileImageKey != widget.post.userProfileImageKey ||
        oldWidget.post.userProfileImageUrl != widget.post.userProfileImageUrl) {
      _fetchProfileImage();
    }
    if (oldWidget.post.audioUrl != widget.post.audioUrl) {
      _fetchAudioUrl(widget.post.audioUrl);
    }
  }

  /// 서버가 내려준 작성자 프로필 URL을 첫 프레임 표시용 값으로 정규화합니다.
  String? _normalizeImageUrl(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  /// 작성자 프로필 key는 캐시와 presigned URL 갱신의 단일 기준으로 사용합니다.
  String? _normalizedProfileImageKey() {
    final normalized = widget.post.userProfileImageKey?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  /// 오디오 카드 작성자 아바타는 서버 URL을 바로 쓰고, 없을 때만 key의 캐시된 presigned URL을 재사용합니다.
  String? _resolveImmediateProfileImageUrl() {
    final immediateUrl = _normalizeImageUrl(widget.post.userProfileImageUrl);
    if (immediateUrl != null) {
      return immediateUrl;
    }

    final profileKey = _normalizedProfileImageKey();
    if (profileKey == null) {
      return null;
    }

    try {
      return context.read<MediaController>().peekPresignedUrl(profileKey);
    } catch (_) {
      return null;
    }
  }

  /// 프로필 key를 우선 캐시 식별자로 쓰고, 없을 때만 URL 기반 식별자를 계산합니다.
  String? _resolveProfileCacheKey() {
    final profileKey = _normalizedProfileImageKey();
    if (profileKey != null) {
      return profileKey;
    }

    final profileImageUrl = _normalizeImageUrl(_profileImageUrl);
    if (profileImageUrl == null) {
      return null;
    }

    final uri = Uri.tryParse(profileImageUrl);
    if (uri == null || !uri.hasScheme) {
      return null;
    }

    final normalizedHost = uri.host.trim();
    final normalizedPath = uri.path.trim();
    if (normalizedPath.isEmpty) {
      return null;
    }

    return normalizedHost.isEmpty
        ? normalizedPath
        : '$normalizedHost$normalizedPath';
  }

  /// 오디오 카드 작성자 아바타는 URL을 먼저 표시하고, key가 있으면 최신 presigned URL로 백그라운드 갱신합니다.
  Future<void> _fetchProfileImage() async {
    if (!mounted) return;
    final requestId = ++_profileLoadGeneration;
    final immediateUrl = _resolveImmediateProfileImageUrl();
    final profileKey = _normalizedProfileImageKey();

    setState(() {
      _profileImageUrl = immediateUrl;
      _isProfileLoading = immediateUrl == null && profileKey != null;
    });

    if (profileKey == null) {
      return;
    }

    try {
      final profileImageUrl = _normalizeImageUrl(
        await context.read<MediaController>().getPresignedUrl(profileKey),
      );
      if (!mounted || requestId != _profileLoadGeneration) return;
      setState(() {
        _profileImageUrl = profileImageUrl ?? immediateUrl;
        _isProfileLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _profileLoadGeneration) return;
      setState(() {
        _profileImageUrl = immediateUrl;
        _isProfileLoading = false;
      });
    }
  }

  Future<void> _fetchAudioUrl(String? audioKey) async {
    if (!mounted) return;

    if (audioKey == null || audioKey.isEmpty) {
      setState(() {
        _audioUrl = null;
        _isAudioLoading = false;
      });
      return;
    }

    final parsed = Uri.tryParse(audioKey);
    if (parsed != null && parsed.hasScheme) {
      setState(() {
        _audioUrl = audioKey;
        _isAudioLoading = false;
      });
      return;
    }

    setState(() => _isAudioLoading = true);
    try {
      final mediaController = Provider.of<MediaController>(
        context,
        listen: false,
      );
      final resolved = await mediaController.getPresignedUrl(audioKey);
      if (!mounted) return;
      setState(() {
        _audioUrl = resolved;
        _isAudioLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _audioUrl = null;
        _isAudioLoading = false;
      });
    }
  }

  String? get _effectiveAudioUrl {
    if (_audioUrl != null && _audioUrl!.isNotEmpty) {
      return _audioUrl;
    }
    final original = widget.post.audioUrl;
    final parsed = original != null ? Uri.tryParse(original) : null;
    if (parsed != null && parsed.hasScheme) {
      return original;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // AudioController Provider가 존재하는 경우 --> 오디오 재생/일시정지 기능 활성화
    if (_hasAudioController(context)) {
      return Consumer<AudioController>(
        builder: (context, audioController, child) {
          final audioSource = _effectiveAudioUrl;
          final isCurrentAudio =
              audioSource != null &&
              audioController.currentAudioUrl == audioSource;
          final progress = isCurrentAudio ? audioController.progress : 0.0;

          return _AudioControlSurface(
            isPlaying: isCurrentAudio && audioController.isPlaying,
            progress: progress,
            waveformData: widget.waveformData,
            duration: Duration(seconds: widget.post.durationInSeconds),
            post: widget.post,
            profileImageUrl: _profileImageUrl,
            profileImageCacheKey: _resolveProfileCacheKey(),
            isProfileLoading: _isProfileLoading,
            isAudioLoading: _isAudioLoading,

            onTap: () {
              final url = _effectiveAudioUrl;
              if (url == null || url.isEmpty) return;
              // 파형 진행률 계산을 위해, 위젯 내부에서 resolve한 URL로 동일하게 재생/일시정지 처리한다.
              audioController.togglePlayPause(url);
            },
          );
        },
      );
    }

    // AudioController Provider가 존재하지 않는 경우 --> 재생 불가 UI 표시
    return _AudioControlSurface(
      isPlaying: false,
      progress: 0,
      waveformData: widget.waveformData,
      duration: Duration(seconds: widget.post.durationInSeconds),
      post: widget.post,
      profileImageUrl: _profileImageUrl,
      profileImageCacheKey: _resolveProfileCacheKey(),
      isProfileLoading: _isProfileLoading,
      isAudioLoading: _isAudioLoading,
      onTap: () {
        if (widget.onPressed != null) {
          widget.onPressed!();
        }
      },
    );
  }

  // AudioController Provider 존재 여부를 확인하는 메소드
  // 존재하지 않으면 예외 발생
  bool _hasAudioController(BuildContext context) {
    try {
      Provider.of<AudioController>(context, listen: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  /*String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }*/
}

// 오디오 컨트롤 UI 서피스
class _AudioControlSurface extends StatelessWidget {
  final bool isPlaying;
  final double progress;
  final List<double>? waveformData;
  final Duration duration;
  final VoidCallback? onTap;
  final Post post;
  final String? profileImageUrl;
  final String? profileImageCacheKey;
  final bool isProfileLoading;
  final bool isAudioLoading;

  const _AudioControlSurface({
    required this.isPlaying,
    required this.progress,
    required this.waveformData,
    required this.duration,
    required this.post,
    required this.profileImageUrl,
    required this.profileImageCacheKey,
    required this.isProfileLoading,
    required this.isAudioLoading,

    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool disableTap = isAudioLoading;
    final borderRadius = BorderRadius.circular(13.6);
    return GestureDetector(
      onTap: disableTap ? null : onTap,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 3.h),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: Colors.black.withValues(alpha: 0.4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildProfileImage(),
              SizedBox(width: (13.79).w),

              // 파형 및 진행률
              Expanded(
                child: SizedBox(
                  height: 30.h,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (waveformData != null)
                        CustomWaveformWidget(
                          waveformData: waveformData!,
                          progress: progress,
                          activeColor: Colors.white,
                          color: Colors.grey[600]!,
                          barThickness: 3.0,
                          barSpacing: 7.0,
                          maxBarHeightFactor: 0.5,
                          amplitudeScale: 1.0,
                          minBarHeight: 0.0,
                          strokeCap: StrokeCap.round,
                        )
                      else
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[600],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      if (isAudioLoading)
                        const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: (15.33).w),
              Text(
                _format(duration),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: (11.86).sp,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Pretendard Variable',
                ),
              ),
              SizedBox(width: (15).w),
            ],
          ),
        ),
      ),
    );
  }

  // 시간 형식 변환 (mm:ss)
  static String _format(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // 프로필 이미지 빌드
  Widget _buildProfileImage() {
    if (isProfileLoading) {
      return SizedBox(
        width: 30.w,
        height: 30.w,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade500),
        ),
      );
    }

    if (profileImageUrl == null || profileImageUrl!.isEmpty) {
      return _placeholderAvatar();
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: profileImageUrl!,
        cacheKey: profileImageCacheKey,
        useOldImageOnUrlChange: profileImageCacheKey != null,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        width: 27,
        height: 27,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _placeholderAvatar() {
    return Container(
      width: 27.sp,
      height: 27.sp,
      decoration: const BoxDecoration(
        color: Colors.grey,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, color: Colors.white, size: 16.sp),
    );
  }
}
