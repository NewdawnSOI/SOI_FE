import 'tag_models.dart';

/// 태그 좌표를 0..1 상대 좌표와 픽셀 좌표 사이에서 변환합니다.
class TagPositionMath {
  const TagPositionMath._();

  static TagPosition normalizeAbsolutePosition({
    required TagPosition absolutePosition,
    required TagViewportSize viewportSize,
  }) {
    if (viewportSize.width <= 0 || viewportSize.height <= 0) {
      return const TagPosition(x: 0.5, y: 0.5);
    }
    return clampUnitPosition(
      TagPosition(
        x: absolutePosition.x / viewportSize.width,
        y: absolutePosition.y / viewportSize.height,
      ),
    );
  }

  static TagPosition denormalizeRelativePosition({
    required TagPosition relativePosition,
    required TagViewportSize viewportSize,
  }) {
    final clamped = clampUnitPosition(relativePosition);
    return TagPosition(
      x: clamped.x * viewportSize.width,
      y: clamped.y * viewportSize.height,
    );
  }

  static TagPosition clampUnitPosition(TagPosition position) {
    return TagPosition(
      x: position.x.clamp(0.0, 1.0).toDouble(),
      y: position.y.clamp(0.0, 1.0).toDouble(),
    );
  }
}
