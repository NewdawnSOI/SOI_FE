import 'package:flutter/material.dart';

/// 음성 댓글 프로필 이미지 위치를 절대 좌표와 상대 좌표 간 변환하는 유틸리티
/// 음성 댓글 작성 시, 사용자가 프로필 이미지를 드래그하여 위치를 지정할 수 있도록 절대 좌표와 상대 좌표 간 변환 기능을 제공합니다.
class PositionConverter {
  /// 절대 좌표(픽셀 단위)를 상대 좌표(0.0 ~ 1.0 범위)로 변환
  /// 절대 좌표를 컨테이너 크기로 나누어 상대 좌표로 변환하고, 0.0 ~ 1.0 범위로 클램핑하여 반환합니다.
  ///
  /// Parameters:
  /// - [absolutePosition]: 절대 좌표 (픽셀 단위)
  /// - [containerSize]: 컨테이너(이미지) 크기
  ///
  /// Returns: 상대 좌표 (0.0 ~ 1.0 범위)
  /// - [Offset]: 상대 좌표로 변환된 Offset 객체를 반환합니다.
  static Offset toRelativePosition(
    Offset absolutePosition, // 절대 좌표 (픽셀 단위)
    Size containerSize, // 컨테이너(이미지) 크기
  ) {
    // 컨테이너 크기가 0인 경우, 상대 좌표 계산이 불가능하므로 (0, 0) 반환
    if (containerSize.width == 0 || containerSize.height == 0) {
      return Offset.zero;
    }

    // 절대 좌표를 컨테이너 크기로 나누어 상대 좌표로 변환하고, 0.0 ~ 1.0 범위로 클램핑
    return Offset(
      (absolutePosition.dx / containerSize.width).clamp(0.0, 1.0),
      (absolutePosition.dy / containerSize.height).clamp(0.0, 1.0),
    );
  }

  /// 상대 좌표(0.0 ~ 1.0 범위)를 절대 좌표(픽셀 단위)로 변환
  /// 상대 좌표를 컨테이너 크기로 곱하여 절대 좌표로 변환합니다.
  ///
  /// Parameters:
  /// - [relativePosition]: 상대 좌표 (0.0 ~ 1.0 범위)
  /// - [containerSize]: 컨테이너(이미지) 크기
  ///
  /// Returns: 절대 좌표 (픽셀 단위)
  /// - [Offset]: 절대 좌표로 변환된 Offset 객체를 반환합니다
  static Offset toAbsolutePosition(
    Offset relativePosition, // 상대 좌표 (0.0 ~ 1.0 범위)
    Size containerSize, // 컨테이너(이미지) 크기
  ) {
    return Offset(
      relativePosition.dx * containerSize.width,
      relativePosition.dy * containerSize.height,
    );
  }
}
