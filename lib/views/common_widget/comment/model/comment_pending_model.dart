import 'dart:ui';

import '../comment_tag_bubble.dart';

/// pending 상태의 프로필 태그의 크기를 정의하는 변수
const double kPendingCommentTagSize = kCommentTagSize;

/// pending 상태 댓글 태그의 회색 배경과 내부 프로필 이미지 사이의 간격을 정의하는 변수
const double kPendingCommentTagPadding = kCommentTagPadding;

/// pending 댓글 태그의 배경 색상을 정의하는 변수
const Color kPendingCommentTagBackgroundColor = Color(0xFF595959);

/// pending 상태의 댓글 태그에서 프로필 이미지가 차지하는 크기를 정의하는 변수
const double kPendingCommentAvatarSize = kCommentTagAvatarSize;

/// API 버전 pending 댓글 UI 마커 정보입니다.
/// - 음성 댓글 녹음 중이거나 텍스트 댓글 입력 중인 상태에서 댓글이 작성될 위치를 보관합니다.
typedef PendingApiCommentMarker = ({
  Offset relativePosition, // 포인터 끝점 기준 상대 좌표
  String? profileImageUrlKey,
  double? progress,
});

/// API 버전 pending 댓글 임시 저장 정보
/// - 음성 댓글 녹음 중이거나 텍스트 댓글 입력 중인 상태에서, 댓글이 작성 중인 내용을 임시로 저장하는 정보
/// - 텍스트 댓글인 경우 텍스트 내용이 저장되고, 음성 댓글인 경우 녹음된 음성 파일 경로와 파형 데이터, 녹음 시간 등이 저장됨
/// - 또한, 댓글 작성자의 사용자 ID와 프로필 이미지 URL 키도 포함하여, UI에서 마커와 임시 저장된 댓글 내용을 연결할 수 있도록 함
typedef PendingApiCommentDraft = ({
  bool isTextComment,
  String? text,
  String? audioPath,
  String? mediaPath,
  bool? isVideo,
  List<double>? waveformData,
  int? duration,
  int recorderUserId,
  String? profileImageUrlKey,
});
