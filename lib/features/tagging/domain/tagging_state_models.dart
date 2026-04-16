import 'dart:ui';

/// 사진 위에 배치되기 전의 pending 태그 위치/진행률을 보관합니다.
typedef TaggingPendingMarker = ({
  Offset relativePosition,
  String? profileImageUrlKey,
  double? progress,
});

/// 저장 전 단계의 텍스트/오디오/미디어 태그 입력값을 보관합니다.
typedef TaggingPendingDraft = ({
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
