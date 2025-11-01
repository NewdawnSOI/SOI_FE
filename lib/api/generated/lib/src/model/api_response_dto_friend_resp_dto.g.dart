// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_response_dto_friend_resp_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApiResponseDtoFriendRespDto _$ApiResponseDtoFriendRespDtoFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ApiResponseDtoFriendRespDto', json, ($checkedConvert) {
  final val = ApiResponseDtoFriendRespDto(
    success: $checkedConvert('success', (v) => v as bool?),
    data: $checkedConvert(
      'data',
      (v) =>
          v == null ? null : FriendRespDto.fromJson(v as Map<String, dynamic>),
    ),
    message: $checkedConvert('message', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$ApiResponseDtoFriendRespDtoToJson(
  ApiResponseDtoFriendRespDto instance,
) => <String, dynamic>{
  'success': ?instance.success,
  'data': ?instance.data?.toJson(),
  'message': ?instance.message,
};
