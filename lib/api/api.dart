// SOI API 래퍼 레이어
//
// 이 파일은 SOI 앱에서 백엔드 API를 사용하기 위한 래퍼 레이어입니다.
// 자동 생성된 OpenAPI 클라이언트를 간편하게 사용할 수 있도록 래핑합니다.
//
// 주요 기능
// - 간편한 API 호출 (복잡한 DTO 래핑 자동 처리)
// - 일관된 에러 핸들링 (SoiApiException 계층 구조)
// - Provider 패턴 지원
// ============================================
// 클라이언트 설정
// ============================================
export 'api_client.dart';

// ============================================
// 예외 클래스
// ============================================
export 'api_exception.dart';

// ============================================
// 서비스 클래스
// ============================================
export 'services/user_service.dart';
export 'services/category_service.dart';
export 'services/post_service.dart';
export 'services/friend_service.dart';
export 'services/comment_service.dart';
export 'services/media_service.dart';
export 'services/notification_service.dart';
export 'services/notification_device_service.dart';
export 'services/report_service.dart';

// ============================================
// 생성된 API 모델 re-export (필요시 직접 사용)
// ============================================
export 'package:soi_api_client/api.dart'
    show
        // 요청 DTO
        AuthCheckReqDto,
        UserCreateReqDto,
        UserUpdateReqDto,
        CategoryCreateReqDto,
        CategoryInviteReqDto,
        CategoryInviteResponseReqDto,
        PostCreateReqDto,
        PostUpdateReqDto,
        FriendCreateReqDto,
        FriendCreateByNickNameReqDto,
        FriendReqDto,
        FriendUpdateRespDto,
        CommentReqDto,
        ReportCreateRequestDto,
        ReportSearchRequestDto,
        ReportUpdateReqDto,
        SortOptionDto,
        // 응답 DTO
        UserRespDto,
        UserFindRespDto,
        CategoryRespDto,
        PostRespDto,
        FriendRespDto,
        FriendCheckRespDto,
        CommentRespDto,
        NotificationRespDto,
        NotificationGetAllRespDto,
        NotificationUserRespDto,
        ReportResponseDto;
