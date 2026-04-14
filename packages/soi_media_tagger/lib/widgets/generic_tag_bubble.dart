import 'package:flutter/material.dart';

/// 제네릭 태그 아바타 태그의 원형 배경과 포인터 기준 좌표계를 공통으로 계산합니다.
class GenericTagBubble extends StatelessWidget {
  const GenericTagBubble({
    super.key,
    required this.child,
    required this.contentSize,
    this.backgroundColor = const Color(0xFF959595),
    this.padding = 3.0,
    this.pointerHeight = 27.0,
    this.pointerOverlap = 2.0,
  });

  final Widget child;
  final double contentSize;
  final Color backgroundColor;
  final double padding;
  final double pointerHeight;
  final double pointerOverlap;

  /// 콘텐츠 크기에 따른 태그 전체 너비 계산 메서드
  static double diameterForContent({
    required double contentSize,
    double padding = 3.0,
  }) {
    return contentSize + (padding * 2);
  }

  /// 콘텐츠 크기에 따른 태그 전체 높이 계산 메서드
  static double totalHeightForContent({
    required double contentSize,
    double padding = 3.0,
    double pointerHeight = 27.0,
    double pointerOverlap = 2.0,
  }) {
    return diameterForContent(contentSize: contentSize, padding: padding) +
        pointerHeight -
        pointerOverlap;
  }

  /// 콘텐츠 크기에 따른 태그 포인터 위치 계산 메서드
  static Offset pointerTipOffset({
    required double contentSize,
    double padding = 3.0,
    double pointerHeight = 27.0,
    double pointerOverlap = 2.0,
  }) {
    // 태그의 원형 부분의 중심에서 포인터의 끝까지의 오프셋 계산
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
