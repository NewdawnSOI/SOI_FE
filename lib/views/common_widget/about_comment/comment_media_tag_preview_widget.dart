import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../api/controller/media_controller.dart';
import '../../../api/models/comment.dart';

/// 댓글에 첨부된 사진이나 영상의 미리보기를 보여주는 위젯입니다.
/// - 사진은 원본 비율로 보여주며, 영상은 1:1 비율로 보여줍니다.
/// - 영상은 자동 재생되며, 소리 재생 여부는 playWithSound 플래그에 따라 결정됩니다.
/// - 미디어 소스는 comment의 fileUrl 또는 fileKey를 통해 결정되며, fileKey가 presigned URL로 변환될 수 있습니다.
/// - 미디어 로딩 중에는 사용자 프로필 사진을 보여주며, 로딩 실패 시에는 기본 이미지 또는 비디오 아이콘을 보여줍니다.
///
/// fields:
/// - [comment]: 미디어 태그가 포함된 댓글 객체입니다. fileUrl, fileKey, userProfileUrl 등의 정보를 포함합니다.
/// - [size]: 미리보기 위젯의 가로세로 크기를 결정하는 값입니다. 사진은 이 크기에 맞춰 원본 비율로 보여지고, 영상은 이 크기에 맞춰 1:1 비율로 보여집니다.
/// - [autoplayVideo]: 영상 미리보기에서 영상을 자동으로 재생할지 여부를 결정하는 플래그입니다. 기본값은 true입니다.
/// - [playWithSound]: 영상 미리보기에서 소리를 재생할지 여부를 결정하는 플래그입니다. 기본값은 true입니다.
class CommentMediaTagPreviewWidget extends StatefulWidget {
  final Comment comment;
  final double size;
  final bool autoplayVideo;
  final bool playWithSound;

  const CommentMediaTagPreviewWidget({
    super.key,
    required this.comment,
    required this.size,
    this.autoplayVideo = true,
    this.playWithSound = true,
  });

  @override
  State<CommentMediaTagPreviewWidget> createState() =>
      _CommentMediaTagPreviewWidgetState();
}

enum _PreviewPhase { loading, ready, failed }

class _CommentMediaTagPreviewWidgetState
    extends State<CommentMediaTagPreviewWidget> {
  String? _resolvedSource;
  bool _isVideo = false;
  _PreviewPhase _phase = _PreviewPhase.loading;

  VideoPlayerController? _videoController;
  Future<void>? _videoInitialization;

  @override
  void initState() {
    super.initState();
    _prepareSource();
  }

  @override
  void didUpdateWidget(covariant CommentMediaTagPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sourceChanged =
        oldWidget.comment.fileKey != widget.comment.fileKey ||
        oldWidget.comment.fileUrl != widget.comment.fileUrl;
    if (sourceChanged) {
      _prepareSource();
      return;
    }

    if (oldWidget.playWithSound != widget.playWithSound) {
      final volume = widget.playWithSound ? 1.0 : 0.0;
      _videoController?.setVolume(volume);
    }
  }

  @override
  void dispose() {
    _disposeVideoController();
    super.dispose();
  }

  Future<void> _prepareSource() async {
    _disposeVideoController();
    if (!mounted) return;

    setState(() {
      _phase = _PreviewPhase.loading;
      _resolvedSource = null;
      _isVideo = false;
    });

    try {
      final source = await _resolveMediaSource(widget.comment);
      if (!mounted) return;

      if (source == null || source.isEmpty) {
        setState(() {
          _phase = _PreviewPhase.failed;
        });
        return;
      }

      final isVideo = _isVideoMediaSource(source);
      if (!isVideo) {
        setState(() {
          _resolvedSource = source;
          _isVideo = false;
          _phase = _PreviewPhase.ready;
        });
        return;
      }

      setState(() {
        _resolvedSource = source;
        _isVideo = true;
        _phase = _PreviewPhase.loading;
      });
      await _initializeVideoController(source);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _PreviewPhase.failed;
      });
    }
  }

  Future<String?> _resolveMediaSource(Comment comment) async {
    final fileUrl = (comment.fileUrl ?? '').trim();
    if (fileUrl.isNotEmpty) {
      return fileUrl;
    }

    final fileKey = (comment.fileKey ?? '').trim();
    if (fileKey.isEmpty) {
      return null;
    }

    final keyUri = Uri.tryParse(fileKey);
    if (keyUri != null && keyUri.hasScheme) {
      return fileKey;
    }

    try {
      final mediaController = context.read<MediaController>();
      return await mediaController.getPresignedUrl(fileKey) ?? fileKey;
    } catch (_) {
      return fileKey;
    }
  }

  bool _isVideoMediaSource(String source) {
    final normalized = source.split('?').first.split('#').first.toLowerCase();
    const videoExtensions = <String>[
      '.mp4',
      '.mov',
      '.m4v',
      '.avi',
      '.mkv',
      '.webm',
    ];
    return videoExtensions.any(normalized.endsWith);
  }

  bool _isLocalFile(String source) {
    final uri = Uri.tryParse(source);
    if (uri == null) {
      return false;
    }
    if (uri.hasScheme) {
      return uri.scheme == 'file';
    }
    return true;
  }

  Future<void> _initializeVideoController(String source) async {
    _disposeVideoController();

    VideoPlayerController? controller;
    try {
      if (_isLocalFile(source)) {
        final file = File(source);
        if (!await file.exists()) {
          if (!mounted) return;
          setState(() {
            _phase = _PreviewPhase.failed;
          });
          return;
        }
        controller = VideoPlayerController.file(file);
      } else {
        controller = VideoPlayerController.networkUrl(Uri.parse(source));
      }

      _videoController = controller;
      _videoInitialization = controller.initialize();
      await _videoInitialization;

      if (!mounted || _videoController != controller) {
        return;
      }

      await controller.setLooping(true);
      await controller.setVolume(widget.playWithSound ? 1.0 : 0.0);
      if (widget.autoplayVideo) {
        await controller.play();
      }

      if (!mounted || _videoController != controller) {
        return;
      }

      setState(() {
        _phase = _PreviewPhase.ready;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _PreviewPhase.failed;
      });
    }
  }

  void _disposeVideoController() {
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    _videoInitialization = null;
  }

  Widget _buildPlaceholder({IconData icon = Icons.image_not_supported}) {
    return Container(
      color: const Color(0xFF4A4A4A),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white70, size: widget.size * 0.28),
    );
  }

  Widget _buildProfileFallback() {
    final profileUrl = (widget.comment.userProfileUrl ?? '').trim();
    if (profileUrl.isEmpty) {
      return Container(
        color: const Color(0xffd9d9d9),
        alignment: Alignment.center,
        child: Icon(
          Icons.person,
          color: Colors.white,
          size: widget.size * 0.28,
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: profileUrl,
      fit: BoxFit.cover,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      memCacheWidth: (widget.size * MediaQuery.of(context).devicePixelRatio)
          .round(),
      placeholder: (_, __) => Container(
        color: const Color(0xffd9d9d9),
        alignment: Alignment.center,
        child: Icon(
          Icons.person,
          color: Colors.white,
          size: widget.size * 0.28,
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        color: const Color(0xffd9d9d9),
        alignment: Alignment.center,
        child: Icon(
          Icons.person,
          color: Colors.white,
          size: widget.size * 0.28,
        ),
      ),
    );
  }

  Widget _buildImagePreview(String source) {
    final isLocal = _isLocalFile(source);
    if (isLocal) {
      final file = File(source);
      if (!file.existsSync()) {
        return _buildPlaceholder();
      }
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    final cacheKey = (widget.comment.fileKey ?? '').trim();
    return CachedNetworkImage(
      imageUrl: source,
      cacheKey: cacheKey.isEmpty ? null : cacheKey,
      useOldImageOnUrlChange: true,
      fit: BoxFit.cover,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => _buildProfileFallback(),
      errorWidget: (_, __, ___) => _buildPlaceholder(),
    );
  }

  Widget _buildVideoPreview() {
    final controller = _videoController;
    final initialization = _videoInitialization;

    if (controller == null || initialization == null) {
      return _buildProfileFallback();
    }

    return FutureBuilder<void>(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            !controller.value.isInitialized) {
          return _buildProfileFallback();
        }

        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        );
      },
    );
  }

  Widget _buildPreviewContent() {
    switch (_phase) {
      case _PreviewPhase.loading:
        return _buildProfileFallback();
      case _PreviewPhase.failed:
        return _isVideo
            ? _buildPlaceholder(icon: Icons.videocam_off)
            : _buildPlaceholder();
      case _PreviewPhase.ready:
        final source = _resolvedSource;
        if (source == null || source.isEmpty) {
          return _buildPlaceholder();
        }
        if (_isVideo) {
          return _buildVideoPreview();
        }
        return _buildImagePreview(source);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildPreviewContent();

    return ClipOval(
      child: SizedBox(width: widget.size, height: widget.size, child: content),
    );
  }
}
