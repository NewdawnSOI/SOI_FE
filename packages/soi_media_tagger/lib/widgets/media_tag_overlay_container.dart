import 'package:flutter/material.dart';

import '../geometry/media_tag_geometry.dart';
import '../models/media_tag.dart';
import '../utils/relative_position_converter.dart';
import 'generic_tag_bubble.dart';

typedef MediaTagBuilder<T> = Widget Function(
  BuildContext context,
  MediaTag<T> tag,
  bool isSelected,
);

class MediaTagOverlayContainer<T> extends StatelessWidget {
  const MediaTagOverlayContainer({
    super.key,
    required this.tags,
    required this.imageSize,
    required this.tagBuilder,
    this.selectedTagId,
    this.hiddenTagIds = const {},
    this.contentSize = 27.0, // Default avatar size
    this.padding = 3.0,
    this.pointerHeight = 27.0,
    this.pointerOverlap = 2.0,
    this.onTagTap,
    this.onTagLongPress,
  });

  final List<MediaTag<T>> tags;
  final Size imageSize;
  final MediaTagBuilder<T> tagBuilder;
  final String? selectedTagId;
  final Set<String> hiddenTagIds;
  
  final double contentSize;
  final double padding;
  final double pointerHeight;
  final double pointerOverlap;

  final void Function(MediaTag<T> tag, Offset tipAnchor)? onTagTap;
  final void Function(MediaTag<T> tag, Offset tipAnchor)? onTagLongPress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: tags.map((tag) {
        if (hiddenTagIds.contains(tag.id)) {
          return const SizedBox.shrink();
        }

        final absolutePos = RelativePositionConverter.toAbsolutePosition(
          tag.relativePosition,
          imageSize,
        );

        final clampedSmallTip = MediaTagGeometry.clampTagAnchor(
          anchor: absolutePos,
          containerSize: imageSize,
          contentSize: contentSize,
          padding: padding,
          pointerHeight: pointerHeight,
          pointerOverlap: pointerOverlap,
        );

        final topLeft = MediaTagGeometry.tagTopLeftFromTipAnchor(
          tipAnchor: clampedSmallTip,
          contentSize: contentSize,
          padding: padding,
          pointerHeight: pointerHeight,
          pointerOverlap: pointerOverlap,
        );

        final isSelected = selectedTagId == tag.id;

        return Positioned(
          left: topLeft.dx,
          top: topLeft.dy,
          child: GestureDetector(
            onTap: () => onTagTap?.call(tag, clampedSmallTip),
            onLongPress: () => onTagLongPress?.call(tag, clampedSmallTip),
            child: GenericTagBubble(
              contentSize: contentSize,
              padding: padding,
              pointerHeight: pointerHeight,
              pointerOverlap: pointerOverlap,
              child: tagBuilder(context, tag, isSelected),
            ),
          ),
        );
      }).toList(),
    );
  }
}
