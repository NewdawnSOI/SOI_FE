import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// 헤더 레이아웃에 필요한 상수 묶음을 한 번에 전달합니다.
class CategoryPhotosHeaderTokens {
  final double expandedHorizontalPadding;
  final double collapsedHorizontalPadding;
  final double expandedTitleBottomInset;
  final double compactTitleVerticalOffset;
  final double toolbarItemVerticalOffset;
  final double collapsedTitleScale;
  final double titleFontSize;

  const CategoryPhotosHeaderTokens({
    required this.expandedHorizontalPadding,
    required this.collapsedHorizontalPadding,
    required this.expandedTitleBottomInset,
    required this.compactTitleVerticalOffset,
    required this.toolbarItemVerticalOffset,
    required this.collapsedTitleScale,
    required this.titleFontSize,
  });
}

/// 헤더 build에서 바로 소비할 계산 결과를 immutable 값으로 제공합니다.
class CategoryPhotosHeaderLayout {
  final double progress;
  final double backgroundOpacity;
  final double expandedInfoOpacity;
  final double compactTitleOpacity;
  final double toolbarOverlayOpacity;
  final double horizontalPadding;
  final double titleTop;
  final double largeTitleScale;
  final double titleFontSize;
  final double topBarItemTop;
  final bool heroEnabled;
  final int decodeWidth;

  const CategoryPhotosHeaderLayout({
    required this.progress,
    required this.backgroundOpacity,
    required this.expandedInfoOpacity,
    required this.compactTitleOpacity,
    required this.toolbarOverlayOpacity,
    required this.horizontalPadding,
    required this.titleTop,
    required this.largeTitleScale,
    required this.titleFontSize,
    required this.topBarItemTop,
    required this.heroEnabled,
    required this.decodeWidth,
  });
}

/// 헤더 스크롤 상태를 화면 좌표와 투명도 값으로 변환합니다.
class CategoryPhotosHeaderLayoutResolver {
  static const double heroEnabledMaxCollapse = 0.92;
  static const double maxToolbarOverlayOpacity = 0.94;

  const CategoryPhotosHeaderLayoutResolver._();

  /// 현재 슬리버 상태와 디자인 토큰으로 헤더 전체 배치 값을 계산합니다.
  static CategoryPhotosHeaderLayout resolve({
    required double minExtent,
    required double maxExtent,
    required double shrinkOffset,
    required double viewportWidth,
    required double devicePixelRatio,
    required CategoryPhotosHeaderTokens tokens,
  }) {
    final collapseRange = (maxExtent - minExtent).clamp(1.0, double.infinity);
    final progress = (shrinkOffset / collapseRange).clamp(0.0, 1.0);
    final easedProgress = Curves.easeInOutCubic.transform(progress);
    final toolbarTop = minExtent - kToolbarHeight;
    final toolbarCenterY = toolbarTop + (kToolbarHeight / 2);
    final expandedTitleTop = maxExtent - tokens.expandedTitleBottomInset;
    final compactTitleTop = toolbarCenterY - tokens.compactTitleVerticalOffset;

    return CategoryPhotosHeaderLayout(
      progress: progress,
      backgroundOpacity: (1.0 - Curves.easeOut.transform(progress)).clamp(
        0.0,
        1.0,
      ),
      expandedInfoOpacity: (1.0 - Curves.easeIn.transform(progress)).clamp(
        0.0,
        1.0,
      ),
      compactTitleOpacity: Curves.easeIn.transform(progress),
      toolbarOverlayOpacity:
          (Curves.easeIn.transform(progress) * maxToolbarOverlayOpacity).clamp(
            0.0,
            1.0,
          ),
      horizontalPadding:
          lerpDouble(
            tokens.expandedHorizontalPadding,
            tokens.collapsedHorizontalPadding,
            easedProgress,
          ) ??
          tokens.collapsedHorizontalPadding,
      titleTop:
          lerpDouble(expandedTitleTop, compactTitleTop, easedProgress) ?? 0,
      largeTitleScale:
          lerpDouble(1.0, tokens.collapsedTitleScale, easedProgress) ?? 1.0,
      titleFontSize: tokens.titleFontSize,
      topBarItemTop: toolbarCenterY - tokens.toolbarItemVerticalOffset,
      heroEnabled: progress < heroEnabledMaxCollapse,
      decodeWidth: math.max(1, (viewportWidth * devicePixelRatio).round()),
    );
  }
}
