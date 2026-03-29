import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../api/controller/media_controller.dart';
import '../../../api/controller/user_controller.dart';

/// 현재 로그인 사용자 이미지 변경만 좁게 구독해 작은 화면 조각만 다시 그리게 합니다.
enum CurrentUserImageKind { profile, cover }

/// fallback 이미지 source와 UserController 선택값을 합쳐 렌더용 URL/cache key를 제공합니다.
class CurrentUserImageBuilder extends StatelessWidget {
  const CurrentUserImageBuilder({
    super.key,
    required this.imageKind,
    required this.builder,
    this.fallbackImageUrl,
    this.fallbackImageKey,
    this.targetUserId,
    this.targetUserHandle,
    this.resolveImageKeyWhenMissing = true,
  });

  final CurrentUserImageKind imageKind;
  final String? fallbackImageUrl; // 선택된 이미지가 없는 경우 대신 사용할 이미지 URL입니다.
  final String? fallbackImageKey; // 선택된 이미지가 없는 경우 대신 사용할 이미지의 캐시 키입니다.
  final int? targetUserId;
  final String? targetUserHandle;
  final bool resolveImageKeyWhenMissing;
  final Widget Function(
    BuildContext context,
    String? imageUrl,
    String? cacheKey,
  )
  builder;

  @override
  Widget build(BuildContext context) {
    return Selector<UserController, UserImageSelection>(
      selector: (_, controller) {
        switch (imageKind) {
          case CurrentUserImageKind.profile:
            // profile은 UserController에서 별도 selector로 분리해 구독 범위를 좁힙니다.
            return controller.selectProfileImage(
              userId: targetUserId,
              nickname: targetUserHandle,
              fallbackImageUrl: fallbackImageUrl,
              fallbackImageKey: fallbackImageKey,
            );
          case CurrentUserImageKind.cover:
            // cover는 UserController에서 별도 selector로 분리해 구독 범위를 좁힙니다.
            return controller.selectCoverImage(
              userId: targetUserId,
              nickname: targetUserHandle,
              fallbackImageUrl: fallbackImageUrl,
              fallbackImageKey: fallbackImageKey,
            );
        }
      },
      builder: (context, selection, _) {
        //
        return _ResolvedCurrentUserImage(
          selection: selection,
          fallbackImageUrl: fallbackImageUrl,
          fallbackImageKey: fallbackImageKey,
          resolveImageKeyWhenMissing: resolveImageKeyWhenMissing,
          builder: builder,
        );
      },
    );
  }
}

class _ResolvedCurrentUserImage extends StatefulWidget {
  ///
  ///
  ///
  const _ResolvedCurrentUserImage({
    required this.selection,
    required this.fallbackImageUrl,
    required this.fallbackImageKey,
    required this.resolveImageKeyWhenMissing,
    required this.builder,
  });

  final UserImageSelection selection;
  final String? fallbackImageUrl;
  final String? fallbackImageKey;
  final bool resolveImageKeyWhenMissing;
  final Widget Function(
    BuildContext context,
    String? imageUrl,
    String? cacheKey,
  )
  builder;

  @override
  State<_ResolvedCurrentUserImage> createState() =>
      _ResolvedCurrentUserImageState();
}

class _ResolvedCurrentUserImageState extends State<_ResolvedCurrentUserImage> {
  String? _resolvedImageUrl;
  int _requestToken = 0;

  @override
  void initState() {
    super.initState();
    _resolvedImageUrl = _resolveImmediateImageUrl();
    _refreshResolvedImageUrl();
  }

  @override
  void didUpdateWidget(covariant _ResolvedCurrentUserImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection != widget.selection ||
        oldWidget.resolveImageKeyWhenMissing !=
            widget.resolveImageKeyWhenMissing) {
      final nextImmediateImageUrl = _resolveImmediateImageUrl();
      if (_resolvedImageUrl != nextImmediateImageUrl) {
        setState(() {
          _resolvedImageUrl = nextImmediateImageUrl;
        });
      }
      _refreshResolvedImageUrl();
    }
  }

  /// 선택된 이미지 URL이 즉시 사용 가능한 경우 반환합니다.
  /// 그렇지 않으면 null을 반환합니다.
  String? _resolveImmediateImageUrl() {
    // 선택된 이미지 URL을 정규화하여
    // 정규화된 URL or null을 반환합니다.
    final normalizedImageUrl = _normalize(widget.selection.imageUrl);

    // 선택된 이미지 URL이 즉시 사용 가능한 경우 반환합니다.
    if (normalizedImageUrl != null) {
      return normalizedImageUrl;
    }

    //
    final normalizedImageKey = _normalize(widget.selection.imageKey);

    // 선택된 이미지 URL이 없고,
    if (normalizedImageKey == null || !_shouldResolveImageKey()) {
      // 이미지 키가 presigned URL로 즉시 변환 가능한 경우가 아니면 null을 반환합니다.
      return null;
    }

    return _normalize(
      context.read<MediaController>().peekPresignedUrl(normalizedImageKey),
    );
  }

  /// 선택된 이미지 키가 presigned URL로 즉시 변환 가능한 경우 반환합니다.
  /// 그렇지 않으면 null을 반환합니다.
  Future<void> _refreshResolvedImageUrl() async {
    final normalizedImageKey = _normalize(widget.selection.imageKey);
    if (normalizedImageKey == null || !_shouldResolveImageKey()) {
      return;
    }

    final requestToken = ++_requestToken;
    final resolvedUrl = await context.read<MediaController>().getPresignedUrl(
      normalizedImageKey,
    );
    if (!mounted || requestToken != _requestToken) {
      return;
    }

    final activeImageKey = _normalize(widget.selection.imageKey);
    if (activeImageKey != normalizedImageKey) {
      return;
    }

    final normalizedResolvedUrl = _normalize(resolvedUrl);
    if (normalizedResolvedUrl == null ||
        normalizedResolvedUrl == _resolvedImageUrl) {
      return;
    }

    setState(() {
      _resolvedImageUrl = normalizedResolvedUrl;
    });
  }

  /// 문자열을 정규화하여
  /// - null 또는 빈 문자열인 경우 null을 반환하고,
  /// - 그렇지 않은 경우 정규화된 값을 반환합니다.
  String? _normalize(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    // null 또는 빈 문자열이 아닌 경우 정규화된 값을 반환합니다.
    return normalized;
  }

  /// 선택된 이미지 URL이 없는 경우 fallback 이미지로 presigned URL을 해석해야 하는지 여부를 반환합니다.
  bool _shouldResolveImageKey() {
    if (widget.resolveImageKeyWhenMissing) {
      return true;
    }

    return _normalize(widget.selection.imageUrl) !=
            _normalize(widget.fallbackImageUrl) ||
        _normalize(widget.selection.imageKey) !=
            _normalize(widget.fallbackImageKey);
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      _resolvedImageUrl,
      _normalize(widget.selection.imageKey),
    );
  }
}
