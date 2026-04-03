import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// 헤더 레이아웃에 필요한 상수 묶음을 한 번에 전달합니다.
class CategoryPhotosHeaderTokens {
  /// 확장 상태에서 타이틀/프로필 Row가 좌우로 확보할 기본 패딩입니다.
  final double expandedHorizontalPadding;

  /// 접힘 상태에 가까워질 때 사용할 더 좁은 좌우 패딩입니다.
  final double collapsedHorizontalPadding;

  /// 확장 상태에서 타이틀 Row를 헤더 하단에서 얼마나 띄울지 결정합니다.
  final double expandedTitleBottomInset;

  /// 접힘 상태에서 타이틀 Row를 툴바 중심선보다 얼마나 위로 올릴지 결정합니다.
  final double compactTitleVerticalOffset;

  /// 좌우 상단 액션 버튼 Row를 툴바 중심선 기준으로 얼마나 위에 둘지 결정합니다.
  final double toolbarItemVerticalOffset;

  /// 스크롤이 접힐 때 큰 타이틀이 최종적으로 줄어드는 배율입니다.
  final double collapsedTitleScale;

  /// 확장 상태 타이틀 텍스트의 기준 폰트 크기입니다.
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
  /// `0.0 ~ 1.0` 범위의 스크롤 진행률입니다. 0은 완전 확장, 1은 완전 접힘입니다.
  final double progress;

  /// 배경 이미지가 얼마나 보일지를 나타내는 투명도 값입니다.
  final double backgroundOpacity;

  /// 확장 상태의 큰 타이틀/프로필 Row가 얼마나 보일지를 나타냅니다.
  final double expandedInfoOpacity;

  /// 접힘 상태의 compact 타이틀이 얼마나 보일지를 나타냅니다.
  final double compactTitleOpacity;

  /// 상단 툴바 오버레이의 어두운 정도를 제어하는 투명도 값입니다.
  final double toolbarOverlayOpacity;

  /// 현재 스크롤 진행률에 맞춰 보간된 좌우 패딩입니다.
  final double horizontalPadding;

  /// 큰 타이틀/프로필 Row를 `Stack` 안에서 어디에 배치할지 결정하는 top 좌표입니다.
  final double titleTop;

  /// 큰 타이틀이 스크롤에 따라 얼마나 축소될지 나타내는 배율입니다.
  final double largeTitleScale;

  /// 큰 타이틀 텍스트에 실제로 적용할 폰트 크기입니다.
  final double titleFontSize;

  /// 뒤로가기/멤버/메뉴 액션 Row를 배치할 top 좌표입니다.
  final double topBarItemTop;

  /// Hero 애니메이션을 아직 유지할 수 있는 스크롤 구간인지 여부입니다.
  final bool heroEnabled;

  /// 배경 이미지 디코딩 시 사용할 목표 가로 픽셀 수입니다.
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
  /// Hero 전환을 유지할 최대 접힘 진행률입니다. 이 값을 넘으면 Hero를 끕니다.
  static const double heroEnabledMaxCollapse = 0.92;

  /// 접힘 상태 오버레이가 가질 최대 불투명도입니다.
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
    /// 헤더가 실제로 줄어들 수 있는 전체 스크롤 구간 길이입니다.
    final collapseRange = (maxExtent - minExtent).clamp(1.0, double.infinity);

    /// 현재 스크롤이 전체 접힘 구간에서 얼마나 진행됐는지 나타내는 정규화 값입니다.
    final progress = (shrinkOffset / collapseRange).clamp(0.0, 1.0);

    /// 위치/스케일 보간을 더 부드럽게 만들기 위해 easing을 적용한 진행률입니다.
    final easedProgress = Curves.easeInOutCubic.transform(progress);

    /// 축소 헤더의 툴바가 시작되는 y 좌표입니다.
    final toolbarTop = minExtent - kToolbarHeight;

    /// 툴바 중앙선 위치로, compact 타이틀과 액션 Row 배치 기준점입니다.
    final toolbarCenterY = toolbarTop + (kToolbarHeight / 2);

    /// 확장 상태에서 큰 타이틀 Row가 놓일 top 좌표입니다.
    final expandedTitleTop = maxExtent - tokens.expandedTitleBottomInset;

    /// 접힘 상태에서 큰 타이틀 Row가 수렴할 compact 기준 top 좌표입니다.
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
