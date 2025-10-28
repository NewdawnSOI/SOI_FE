import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';

// 이미지를 표시하는 위젯
// 로컬 이미지 경로나 Firebase Storage URL을 기반으로 이미지를 표시합니다.
class PhotoDisplayWidget extends StatefulWidget {
  final String? filePath;
  final String? downloadUrl;
  final bool useLocalImage;
  final bool useDownloadUrl;
  final double width;
  final double height;
  final bool isVideo;
  final Future<void> Function()? onCancel;

  const PhotoDisplayWidget({
    super.key,
    this.filePath,
    this.downloadUrl,
    required this.useLocalImage,
    required this.useDownloadUrl,
    this.width = 354,
    this.height = 471,
    this.isVideo = false,
    this.onCancel,
  });

  @override
  State<PhotoDisplayWidget> createState() => _PhotoDisplayWidgetState();
}

class _PhotoDisplayWidgetState extends State<PhotoDisplayWidget> {
  VideoPlayerController? _videoController;
  Future<void>? _initializeVideoPlayerFuture;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() {
    // 중복 초기화 방지
    if (_isInitialized) {
      return;
    }

    // 비디오인 경우에만 VideoPlayerController 초기화
    if (widget.isVideo && widget.filePath != null) {
      _isInitialized = true;
      _videoController = VideoPlayerController.file(File(widget.filePath!));
      _initializeVideoPlayerFuture = _videoController!
          .initialize()
          .then((_) {
            // 초기화 완료 후 자동 재생 및 루프 설정
            _videoController!.setLooping(true);
            _videoController!.play();
            if (mounted) setState(() {});
          })
          .catchError((error) {
            debugPrint("비디오 초기화 에러: $error");
          });
    }
  }

  @override
  void dispose() {
    // 이미지 캐시에서 해당 이미지 제거
    try {
      if (widget.filePath != null) {
        PaintingBinding.instance.imageCache.evict(
          FileImage(File(widget.filePath!)),
        );
      }
      if (widget.downloadUrl != null) {
        PaintingBinding.instance.imageCache.evict(
          NetworkImage(widget.downloadUrl!),
        );
      }
    } catch (e) {
      // 캐시 제거 실패해도 계속 진행
      debugPrint('Error evicting image from cache: $e');
    }

    // 비디오 컨트롤러가 초기화된 경우에만 dispose
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.0),
        child:
            (widget.isVideo) ? _buildVideoPlayer() : _buildImageWidget(context),
      ),
    );
  }

  /// 이미지 위젯을 결정하는 메소드
  Widget _buildImageWidget(BuildContext context) {
    // 로컬 이미지를 우선적으로 사용
    if (widget.useLocalImage && widget.filePath != null) {
      return Stack(
        alignment: Alignment.topLeft,
        children: [
          Image.file(
            File(widget.filePath!),
            width: widget.width,
            height: widget.height,
            fit: BoxFit.cover,
            // 메모리 최적화: 이미지 캐시 크기 제한
            cacheWidth: (widget.width * 2).round(),
            cacheHeight: (widget.height * 2).round(),

            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.error, color: Colors.white);
            },
          ),
          IconButton(
            onPressed: () async {
              await _handleCancel(doublePop: true);
            },
            icon: Icon(Icons.cancel, color: Color(0xff1c1b1f), size: 35.sp),
          ),
        ],
      );
    }
    // 사진 보여주기
    else if (widget.useDownloadUrl && widget.downloadUrl != null) {
      return Stack(
        alignment: Alignment.topLeft,
        children: [
          CachedNetworkImage(
            imageUrl: widget.downloadUrl!,
            width: widget.width, // 354.w
            height: widget.height, // 500.h
            fit: BoxFit.cover,
            // 메모리 최적화: 실제 표시 크기의 2배로 레티나 디스플레이 대응
            memCacheWidth: (widget.width * 2).round(),
            maxWidthDiskCache: (widget.width * 2).round(),
            placeholder:
                (context, url) =>
                    const Center(child: CircularProgressIndicator()),
            errorWidget:
                (context, url, error) =>
                    const Icon(Icons.error, color: Colors.white),
          ),
          IconButton(
            onPressed: () async {
              await _handleCancel(doublePop: false);
            },
            icon: Icon(
              Icons.cancel,
              color: Color.fromARGB(255, 17, 15, 22).withValues(alpha: 0.8),
              size: 30.sp,
            ),
          ),
        ],
      );
    }
    // 둘 다 없는 경우 에러 메시지 표시
    else {
      return const Center(
        child: Text("이미지를 불러올 수 없습니다.", style: TextStyle(color: Colors.white)),
      );
    }
  }

  Widget _buildVideoPlayer() {
    // 비디오 컨트롤러가 없으면 에러 표시
    if (_videoController == null || _initializeVideoPlayerFuture == null) {
      return const Center(
        child: Text("비디오를 불러올 수 없습니다.", style: TextStyle(color: Colors.white)),
      );
    }

    return FutureBuilder(
      future: _initializeVideoPlayerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Future<void> _handleCancel({required bool doublePop}) async {
    if (widget.onCancel != null) {
      await widget.onCancel!();
    }

    if (!mounted) return;

    final navigator = Navigator.of(context);
    navigator.pop();

    if (doublePop && navigator.canPop()) {
      navigator.pop();
    }
  }
}
