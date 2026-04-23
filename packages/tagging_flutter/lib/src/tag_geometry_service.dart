import 'dart:ui';

import 'tag_bubble.dart';

/// 태그 버블의 anchor와 top-left를 media bounds 안에서 계산합니다.
class TagGeometryService {
  const TagGeometryService._();

  static Offset clampTagAnchor(
    Offset anchor,
    Size containerSize,
    double contentSize, {
    double padding = 3.0,
  }) {
    final diameter = TagBubble.diameterForContent(
      contentSize: contentSize,
      padding: padding,
    );
    final tipOffset = TagBubble.pointerTipOffset(
      contentSize: contentSize,
      padding: padding,
    );
    final minX = diameter / 2;
    final maxX = containerSize.width - diameter / 2;
    final minY = tipOffset.dy;
    final maxY = containerSize.height;

    return Offset(anchor.dx.clamp(minX, maxX), anchor.dy.clamp(minY, maxY));
  }

  static Offset tagCircleCenterFromTipAnchor(
    Offset tipAnchor,
    double contentSize, {
    double padding = 3.0,
  }) {
    final tipOffset = TagBubble.pointerTipOffset(
      contentSize: contentSize,
      padding: padding,
    );
    final diameter = TagBubble.diameterForContent(
      contentSize: contentSize,
      padding: padding,
    );
    final left = tipAnchor.dx - tipOffset.dx;
    final top = tipAnchor.dy - tipOffset.dy;
    return Offset(left + (diameter / 2), top + (diameter / 2));
  }

  static Offset tagTopLeftFromTipAnchor(
    Offset tipAnchor,
    double contentSize, {
    double padding = 3.0,
  }) {
    final tipOffset = TagBubble.pointerTipOffset(
      contentSize: contentSize,
      padding: padding,
    );
    return Offset(tipAnchor.dx - tipOffset.dx, tipAnchor.dy - tipOffset.dy);
  }
}
