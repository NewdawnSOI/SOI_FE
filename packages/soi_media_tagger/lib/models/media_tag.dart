import 'package:flutter/material.dart';

/// 제네릭 데이터(T)를 포함할 수 있는 미디어 태그 데이터 모델
/// 미디어 외부와 내부 오버레이 사이에 태그 위치 및 식별값을 주고받기 위해 사용합니다.
class MediaTag<T> {
  MediaTag({
    required this.id,
    required this.relativePosition,
    required this.content,
  });

  /// 태그의 고유 식별자
  final String id;

  /// 비율로 된 상대 좌표 (0.0 ~ 1.0)
  final Offset relativePosition;

  /// 태그가 감싸는 실제 도메인 데이터 (예: Comment)
  final T content;

  MediaTag<T> copyWith({
    String? id,
    Offset? relativePosition,
    T? content,
  }) {
    return MediaTag<T>(
      id: id ?? this.id,
      relativePosition: relativePosition ?? this.relativePosition,
      content: content ?? this.content,
    );
  }
}
