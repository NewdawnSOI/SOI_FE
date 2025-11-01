// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_response_dto_user_resp_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApiResponseDtoUserRespDto _$ApiResponseDtoUserRespDtoFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ApiResponseDtoUserRespDto', json, ($checkedConvert) {
  final val = ApiResponseDtoUserRespDto(
    success: $checkedConvert('success', (v) => v as bool?),
    data: $checkedConvert(
      'data',
      (v) => v == null ? null : UserRespDto.fromJson(v as Map<String, dynamic>),
    ),
    message: $checkedConvert('message', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$ApiResponseDtoUserRespDtoToJson(
  ApiResponseDtoUserRespDto instance,
) => <String, dynamic>{
  'success': ?instance.success,
  'data': ?instance.data?.toJson(),
  'message': ?instance.message,
};
