import 'package:flutter/material.dart';

import 'tag_specs.dart';

const double kTagBubblePointerHeight = 27.0;
const double kTagBubblePointerOverlap = 2.0;

/// 태그 아바타의 원형 배경과 포인터 기준 좌표계를 공통으로 계산합니다.
class TagBubble extends StatelessWidget {
  const TagBubble({
    super.key,
    required this.child,
    required this.contentSize,
    this.backgroundColor = const Color(0xFF959595),
    this.padding = TagProfileTagSpec.padding,
    this.pointerHeight = kTagBubblePointerHeight,
    this.pointerOverlap = kTagBubblePointerOverlap,
  });

  final Widget child;
  final double contentSize;
  final Color backgroundColor;
  final double padding;
  final double pointerHeight;
  final double pointerOverlap;

  static double diameterForContent({
    required double contentSize,
    double padding = TagProfileTagSpec.padding,
  }) {
    return contentSize + (padding * 2);
  }

  static double totalHeightForContent({
    required double contentSize,
    double padding = TagProfileTagSpec.padding,
    double pointerHeight = kTagBubblePointerHeight,
    double pointerOverlap = kTagBubblePointerOverlap,
  }) {
    return diameterForContent(contentSize: contentSize, padding: padding) +
        pointerHeight -
        pointerOverlap;
  }

  static Offset pointerTipOffset({
    required double contentSize,
    double padding = TagProfileTagSpec.padding,
    double pointerHeight = kTagBubblePointerHeight,
    double pointerOverlap = kTagBubblePointerOverlap,
  }) {
    final diameter = diameterForContent(
      contentSize: contentSize,
      padding: padding,
    );
    return Offset(diameter / 2, diameter + pointerHeight - pointerOverlap);
  }

  @override
  Widget build(BuildContext context) {
    final diameter = diameterForContent(
      contentSize: contentSize,
      padding: padding,
    );
    final totalHeight = totalHeightForContent(
      contentSize: contentSize,
      padding: padding,
      pointerHeight: pointerHeight,
      pointerOverlap: pointerOverlap,
    );

    return SizedBox(
      width: diameter,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ],
      ),
    );
  }
}
