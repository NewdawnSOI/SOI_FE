import 'package:flutter/material.dart';

class RelativePositionConverter {
  /// 절대 좌표(픽셀 단위)를 상대 좌표(0.0 ~ 1.0 범위)로 변환
  static Offset toRelativePosition(
    Offset absolutePosition,
    Size containerSize,
  ) {
    if (containerSize.width == 0 || containerSize.height == 0) {
      return Offset.zero;
    }

    return Offset(
      (absolutePosition.dx / containerSize.width).clamp(0.0, 1.0),
      (absolutePosition.dy / containerSize.height).clamp(0.0, 1.0),
    );
  }

  /// 상대 좌표(0.0 ~ 1.0 범위)를 절대 좌표(픽셀 단위)로 변환
  static Offset toAbsolutePosition(
    Offset relativePosition,
    Size containerSize,
  ) {
    return Offset(
      relativePosition.dx * containerSize.width,
      relativePosition.dy * containerSize.height,
    );
  }
}
