import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../api/models/comment.dart';
import 'widget/about_comment_list_sheet/api_comment_row.dart';

/// 댓글 리스트를 보여주는 바텀 시트
/// Comment.dart(Model)을 사용하여 댓글 정보를 표시합니다.
/// API의 CommentRespDto와 달리, Comment 모델은 UI/도메인 레이어에서 사용하기 위한 모델입니다.
class ApiVoiceCommentListSheet extends StatefulWidget {
  final int postId;
  final List<Comment> comments;
  final String? selectedCommentId;
  final ScrollController? listScrollController;

  const ApiVoiceCommentListSheet({
    super.key,
    required this.postId,
    required this.comments,
    this.selectedCommentId,
    this.listScrollController,
  });

  @override
  State<ApiVoiceCommentListSheet> createState() =>
      _ApiVoiceCommentListSheetState();
}

class _ApiVoiceCommentListSheetState extends State<ApiVoiceCommentListSheet> {
  late final ScrollController _scrollController;
  late final bool _ownsScrollController;
  bool get _isDraggableMode =>
      widget.listScrollController !=
      null; // listScrollController가 주어지면 드래그 가능한 시트로 간주

  /// 선택된 댓글 ID에서 해시코드를 추출하는 함수
  int? _selectedHashCode(String? selectedCommentId) {
    if (selectedCommentId == null) return null;
    final parts = selectedCommentId.split('_');
    if (parts.length < 2) return null;
    return int.tryParse(parts.last);
  }

  @override
  void initState() {
    super.initState();
    _scrollController = widget.listScrollController ?? ScrollController();
    _ownsScrollController = widget.listScrollController == null;

    if (widget.selectedCommentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedComment();
      });
    }
  }

  @override
  void dispose() {
    if (_ownsScrollController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  /// 댓글 리스트가 처음 열릴 때, 선택된 댓글이 있으면 해당 댓글로 스크롤하는 함수
  void _scrollToSelectedComment() {
    if (widget.selectedCommentId == null) return;

    final targetHash = _selectedHashCode(widget.selectedCommentId);
    if (targetHash == null) return;

    final filteredComments = widget.comments.toList();
    final targetIndex = filteredComments.indexWhere(
      (comment) => comment.hashCode == targetHash,
    );
    if (targetIndex < 0) return;

    if (_scrollController.hasClients) {
      const itemHeight = 80.0;
      const separatorHeight = 12.0;
      final scrollOffset = targetIndex * (itemHeight + separatorHeight);

      final viewportHeight = _scrollController.position.viewportDimension;
      final centeredOffset =
          scrollOffset - (viewportHeight / 2) + (itemHeight / 2);

      _scrollController.jumpTo(
        centeredOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1c1c1c),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24.8),
          topRight: Radius.circular(24.8),
        ),
      ),
      padding: EdgeInsets.only(bottom: 10.sp),
      child: Column(
        mainAxisSize: _isDraggableMode ? MainAxisSize.max : MainAxisSize.min,
        children: [
          SizedBox(height: 3.sp),
          Text(
            "댓글",
            style: TextStyle(
              color: const Color(0xFFF8F8F8),
              fontSize: 18.sp,
              fontFamily: 'Pretendard Variable',
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 15.sp),
          _buildCommentList(),
          SizedBox(height: 10.sp),
          _buildCommentActionBar(),
        ],
      ),
    );
  }

  Widget _buildCommentList() {
    final filteredComments = widget.comments.toList();
    final selectedHash = _selectedHashCode(widget.selectedCommentId);

    // 드래그 가능한 시트가 아닐 때,
    // 댓글이 없으면 "댓글이 없습니다" 메시지를 보여주고,
    // 댓글이 있으면 스크롤이 불가능한 리스트로 표시하는 부분
    if (!_isDraggableMode) {
      // 댓글이 없을 때, "댓글이 없습니다" 메시지를 보여주는 부분
      if (filteredComments.isEmpty) {
        return SizedBox(
          height: 120.sp,
          child: Center(
            child: Text(
              '댓글이 없습니다',
              style: TextStyle(
                color: const Color(0xFF9E9E9E),
                fontSize: 16.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }

      // 댓글이 있을 때, 스크롤이 불가능한 리스트로 표시하는 ListView 위젯
      return ListView.separated(
        controller: _scrollController,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        primary: false,
        itemCount: filteredComments.length,
        separatorBuilder: (_, __) => SizedBox(height: 12.sp),
        itemBuilder: (context, index) {
          final comment = filteredComments[index];
          final isHighlighted =
              selectedHash != null && comment.hashCode == selectedHash;
          return ApiCommentRow(comment: comment, isHighlighted: isHighlighted);
        },
      );
    }

    return Flexible(
      child: filteredComments.isEmpty
          ? Center(
              child: Text(
                '댓글이 없습니다',
                style: TextStyle(
                  color: const Color(0xFF9E9E9E),
                  fontSize: 16.sp,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          :
            // 음성 댓글 목록을 스크롤 가능한 리스트로 표시하는 ListView 위젯
            ListView.separated(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              primary: false,
              itemCount: filteredComments.length,
              separatorBuilder: (_, __) => SizedBox(height: 12.sp),
              itemBuilder: (context, index) {
                final comment = filteredComments[index];
                final isHighlighted =
                    selectedHash != null && comment.hashCode == selectedHash;
                // 각 댓글을 ApiCommentRow 위젯으로 표시하는 부분
                return ApiCommentRow(
                  comment: comment,
                  isHighlighted: isHighlighted,
                );
              },
            ),
    );
  }

  /// CommentListSheet 내부에 있는 댓글 추가 액션 바
  Widget _buildCommentActionBar() {
    return Center(
      child: Container(
        width: 353.sp,
        height: 46.sp,
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(52.r),
        ),
        padding: EdgeInsets.symmetric(horizontal: 10.sp),
        child: Row(
          children: [
            IconButton(
              onPressed: () {},
              padding: EdgeInsets.zero,
              icon: Container(
                width: 32.sp,
                height: 32.sp,
                decoration: ShapeDecoration(
                  color: const Color(0xFF323232),
                  shape: const CircleBorder(),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/camera_mode.png',
                    width: (17.78).sp,
                    height: 16.sp,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.sp),

            // "댓글 추가" 텍스트
            Expanded(
              child: Text(
                tr('comments.add_comment'),
                style: TextStyle(
                  color: const Color(0xFFF8F8F8),
                  fontSize: 16.sp,
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w200,
                  letterSpacing: -1.14,
                ),
              ),
            ),
            IconButton(
              onPressed: () {},
              padding: EdgeInsets.zero,
              icon: Image.asset(
                'assets/record_icon.png',
                width: 36.sp,
                height: 36.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
