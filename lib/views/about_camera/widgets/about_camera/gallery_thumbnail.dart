import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:photo_manager/photo_manager.dart';
import 'camera_shimmer_box.dart';

/// 갤러리 썸네일을 표시하는 위젯입니다.
/// 갤러리에서 선택한 이미지나 비디오의 썸네일을 보여줍니다.
class GalleryThumbnail extends StatefulWidget {
  const GalleryThumbnail({
    required this.isLoading,
    required this.asset,
    required this.errorMessage,
    this.size = 46,
    this.borderRadius = 8.0,
    super.key,
  });

  final bool isLoading;
  final AssetEntity? asset;
  final String? errorMessage;
  final double size;
  final double borderRadius;

  @override
  State<GalleryThumbnail> createState() => _GalleryThumbnailState();
}

class _GalleryThumbnailState extends State<GalleryThumbnail> {
  Future<Uint8List?>? _thumbnailFuture;
  String? _thumbnailAssetId;
  double? _thumbnailSize;

  @override
  void initState() {
    super.initState();
    _syncThumbnailFuture();
  }

  @override
  void didUpdateWidget(covariant GalleryThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncThumbnailFuture();
  }

  void _syncThumbnailFuture() {
    final asset = widget.asset;
    if (asset == null) {
      _thumbnailFuture = null;
      _thumbnailAssetId = null;
      _thumbnailSize = null;
      return;
    }

    if (_thumbnailAssetId == asset.id && _thumbnailSize == widget.size) {
      return;
    }

    final dimension = math.max(48, (widget.size * 2).round());
    _thumbnailFuture = asset.thumbnailDataWithSize(
      ThumbnailSize.square(dimension),
    );
    _thumbnailAssetId = asset.id;
    _thumbnailSize = widget.size;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return _buildShimmer();
    }

    if (widget.errorMessage != null) {
      return _buildPlaceholder();
    }

    if (widget.asset != null && _thumbnailFuture != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: FutureBuilder<Uint8List?>(
          future: _thumbnailFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return Image.memory(
                snapshot.data!,
                width: widget.size.w,
                height: widget.size.h,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholder();
                },
              );
            } else if (snapshot.hasError) {
              return _buildPlaceholder();
            }

            return _buildShimmer();
          },
        ),
      );
    }

    return _buildPlaceholder();
  }

  /// 갤러리 썸네일 로드 실패 시 표시되는 플레이스홀더 위젯입니다.
  Widget _buildPlaceholder() {
    // 로드 실패 시 정적 아이콘 표시 (shimmer와 구분하여 사용자 혼란 방지)
    return Container(
      width: widget.size.w,
      height: widget.size.h,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: Icon(
        Icons.photo_library,
        color: Colors.grey[600],
        size: widget.size * 0.5,
      ),
    );
  }

  Widget _buildShimmer() {
    return CameraShimmerBox(
      width: widget.size.w,
      height: widget.size.h,
      borderRadius: widget.borderRadius,
    );
  }
}
