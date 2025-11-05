/// API 서비스 및 공통 클래스 Export
///
/// lib/api 아래의 모든 서비스와 공통 클래스를 한 곳에서 export
library;

// Common
export 'common/api_client.dart';
export 'common/api_exception.dart';
export 'common/api_result.dart';

// Services
export 'services/user_service.dart';
export 'services/friend_service.dart';
export 'services/media_service.dart';

// OpenAPI Generated (필요한 경우 직접 사용)
export 'package:soi_api/api.dart'
    show
        UserRespDto,
        UserCreateReqDto,
        UserFindRespDto,
        FriendRespDto,
        FriendReqDto,
        FriendUpdateRespDto,
        FriendUpdateRespDtoStatusEnum,
        ApiResponseDtoBoolean,
        ApiResponseDtoString,
        ApiResponseDtoListString,
        ApiResponseDtoUserRespDto,
        ApiResponseDtoListUserRespDto,
        ApiResponseDtoListUserFindRespDto,
        ApiResponseDtoFriendRespDto;
