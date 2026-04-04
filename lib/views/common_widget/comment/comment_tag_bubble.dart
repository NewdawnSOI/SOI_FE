import 'package:flutter/material.dart';
import 'comment_tag_specs.dart';

/// 댓글 태그의 포인터 높이입니다.
const double kCommentTagPointerHeight = 27.0;

/// 댓글 태그의 포인터가 원형 배경과 겹치는 부분의 크기입니다.
/// - 이 값은 포인터가 배경과 자연스럽게 연결되도록 조정하는 데 사용됩니다.
const double kCommentTagPointerOverlap = 2.0;

/// 댓글 아바타 태그의 원형 배경과 포인터 기준 좌표계를 공통으로 계산합니다.
class CommentTagBubble extends StatelessWidget {
  const CommentTagBubble({
    super.key,
    required this.child,
    required this.contentSize,
    this.backgroundColor = const Color(0xFF959595),
    this.padding = CommentProfileTagSpec.padding,
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
    double padding = CommentProfileTagSpec.padding,
  }) {
    return contentSize + (padding * 2);
  }

  /// 표준 댓글 태그의 원형 외곽 지름을 반환합니다.
  static double standardDiameter() {
    return diameterForContent(contentSize: CommentProfileTagSpec.avatarSize);
  }

  /// 콘텐츠 크기에 따른 태그 전체 높이 계산 메서드
  static double totalHeightForContent({
    required double contentSize,
    double padding = CommentProfileTagSpec.padding,
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
    double padding = CommentProfileTagSpec.padding,
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
