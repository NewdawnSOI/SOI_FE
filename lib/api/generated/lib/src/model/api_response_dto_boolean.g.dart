// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_response_dto_boolean.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApiResponseDtoBoolean _$ApiResponseDtoBooleanFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ApiResponseDtoBoolean', json, ($checkedConvert) {
  final val = ApiResponseDtoBoolean(
    success: $checkedConvert('success', (v) => v as bool?),
    data: $checkedConvert('data', (v) => v as bool?),
    message: $checkedConvert('message', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$ApiResponseDtoBooleanToJson(
  ApiResponseDtoBoolean instance,
) => <String, dynamic>{
  'success': ?instance.success,
  'data': ?instance.data,
  'message': ?instance.message,
};
