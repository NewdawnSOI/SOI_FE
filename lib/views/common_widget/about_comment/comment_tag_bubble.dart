import 'package:flutter/material.dart';

const double kCommentTagPadding = 4.0;
const double kCommentTagPointerHeight = 27.0;
const double kCommentTagPointerOverlap = 2.0;

/// 댓글 아바타 태그의 원형 배경과 포인터 기준 좌표계를 공통으로 계산합니다.
class CommentTagBubble extends StatelessWidget {
  const CommentTagBubble({
    super.key,
    required this.child,
    required this.contentSize,
    this.backgroundColor = const Color(0xFF959595),
    this.padding = kCommentTagPadding,
    this.pointerHeight = kCommentTagPointerHeight,
    this.pointerOverlap = kCommentTagPointerOverlap,
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
    double padding = kCommentTagPadding,
  }) {
    return contentSize + (padding * 2);
  }

  /// 콘텐츠 크기에 맞는 원형 버블의 중심 오프셋을 계산합니다.
  static Offset circleCenterOffset({
    required double contentSize,
    double padding = kCommentTagPadding,
  }) {
    final diameter = diameterForContent(
      contentSize: contentSize,
      padding: padding,
    );
    return Offset(diameter / 2, diameter / 2);
  }

  /// 콘텐츠 크기에 따른 태그 전체 높이 계산 메서드
  static double totalHeightForContent({
    required double contentSize,
    double padding = kCommentTagPadding,
    double pointerHeight = kCommentTagPointerHeight,
    double pointerOverlap = kCommentTagPointerOverlap,
  }) {
    return diameterForContent(contentSize: contentSize, padding: padding) +
        pointerHeight -
        pointerOverlap;
  }

  /// 콘텐츠 크기에 따른 태그 포인터 위치 계산 메서드
  static Offset pointerTipOffset({
    required double contentSize,
    double padding = kCommentTagPadding,
    double pointerHeight = kCommentTagPointerHeight,
    double pointerOverlap = kCommentTagPointerOverlap,
  }) {
    // 태그의 원형 부분의 중심에서 포인터의 끝까지의 오프셋 계산
    final diameter = diameterForContent(
      contentSize: contentSize,
      padding: padding,
    );
    return Offset(diameter / 2, diameter + pointerHeight - pointerOverlap);
  }

  /// 원형 중심 좌표를 기존 댓글 좌표계의 포인터 끝점 좌표로 변환합니다.
  static Offset pointerTipFromCircleCenter({
    required Offset circleCenter,
    required double contentSize,
    double padding = kCommentTagPadding,
    double pointerHeight = kCommentTagPointerHeight,
    double pointerOverlap = kCommentTagPointerOverlap,
  }) {
    final centerOffset = circleCenterOffset(
      contentSize: contentSize,
      padding: padding,
    );
    final tipOffset = pointerTipOffset(
      contentSize: contentSize,
      padding: padding,
      pointerHeight: pointerHeight,
      pointerOverlap: pointerOverlap,
    );
    return circleCenter + (tipOffset - centerOffset);
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
