import 'dart:ui';

import '../../../../api/models/comment.dart';
import '../../about_comment/comment_tag_bubble.dart';

class ApiPhotoTagGeometryService {
  const ApiPhotoTagGeometryService._();

  static Offset clampTagAnchor(
    Offset anchor,
    Size containerSize,
    double contentSize,
  ) {
    final diameter = CommentTagBubble.diameterForContent(
      contentSize: contentSize,
    );
    final tipOffset = CommentTagBubble.pointerTipOffset(
      contentSize: contentSize,
    );
    final minX = diameter / 2;
    final maxX = containerSize.width - diameter / 2;
    final minY = tipOffset.dy;
    final maxY = containerSize.height;

    return Offset(anchor.dx.clamp(minX, maxX), anchor.dy.clamp(minY, maxY));
  }

  static Offset tagCircleCenterFromTipAnchor(
    Offset tipAnchor,
    double contentSize,
  ) {
    final tipOffset = CommentTagBubble.pointerTipOffset(
      contentSize: contentSize,
    );
    final diameter = CommentTagBubble.diameterForContent(
      contentSize: contentSize,
    );
    final left = tipAnchor.dx - tipOffset.dx;
    final top = tipAnchor.dy - tipOffset.dy;
    return Offset(left + (diameter / 2), top + (diameter / 2));
  }

  static Offset tagTopLeftFromTipAnchor(Offset tipAnchor, double contentSize) {
    final tipOffset = CommentTagBubble.pointerTipOffset(
      contentSize: contentSize,
    );
    return Offset(tipAnchor.dx - tipOffset.dx, tipAnchor.dy - tipOffset.dy);
  }

  static bool canExpandMediaComment(Comment comment) {
    if (comment.type != CommentType.photo) {
      return false;
    }

    final fileUrl = (comment.fileUrl ?? '').trim();
    if (fileUrl.isNotEmpty) {
      return true;
    }

    final fileKey = (comment.fileKey ?? '').trim();
    return fileKey.isNotEmpty;
  }
}
