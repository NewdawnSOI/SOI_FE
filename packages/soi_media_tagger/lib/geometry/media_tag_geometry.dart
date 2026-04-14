import 'dart:ui';
import '../widgets/generic_tag_bubble.dart';

class MediaTagGeometry {
  const MediaTagGeometry._();

  static Offset clampTagAnchor({
    required Offset anchor,
    required Size containerSize,
    required double contentSize,
    double padding = 3.0,
    double pointerHeight = 27.0,
    double pointerOverlap = 2.0,
  }) {
    final diameter = GenericTagBubble.diameterForContent(
      contentSize: contentSize,
      padding: padding,
    );
    final tipOffset = GenericTagBubble.pointerTipOffset(
      contentSize: contentSize,
      padding: padding,
      pointerHeight: pointerHeight,
      pointerOverlap: pointerOverlap,
    );
    final minX = diameter / 2;
    final maxX = containerSize.width - diameter / 2;
    final minY = tipOffset.dy;
    final maxY = containerSize.height;

    return Offset(anchor.dx.clamp(minX, maxX), anchor.dy.clamp(minY, maxY));
  }

  static Offset tagCircleCenterFromTipAnchor({
    required Offset tipAnchor,
    required double contentSize,
    double padding = 3.0,
    double pointerHeight = 27.0,
    double pointerOverlap = 2.0,
  }) {
    final tipOffset = GenericTagBubble.pointerTipOffset(
      contentSize: contentSize,
      padding: padding,
      pointerHeight: pointerHeight,
      pointerOverlap: pointerOverlap,
    );
    final diameter = GenericTagBubble.diameterForContent(
      contentSize: contentSize,
      padding: padding,
    );
    final left = tipAnchor.dx - tipOffset.dx;
    final top = tipAnchor.dy - tipOffset.dy;
    return Offset(left + (diameter / 2), top + (diameter / 2));
  }

  static Offset tagTopLeftFromTipAnchor({
    required Offset tipAnchor,
    required double contentSize,
    double padding = 3.0,
    double pointerHeight = 27.0,
    double pointerOverlap = 2.0,
  }) {
    final tipOffset = GenericTagBubble.pointerTipOffset(
      contentSize: contentSize,
      padding: padding,
      pointerHeight: pointerHeight,
      pointerOverlap: pointerOverlap,
    );
    return Offset(tipAnchor.dx - tipOffset.dx, tipAnchor.dy - tipOffset.dy);
  }
}
