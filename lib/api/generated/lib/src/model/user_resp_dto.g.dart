// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_resp_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserRespDto _$UserRespDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('UserRespDto', json, ($checkedConvert) {
      final val = UserRespDto(
        id: $checkedConvert('id', (v) => (v as num?)?.toInt()),
        userId: $checkedConvert('userId', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$UserRespDtoToJson(UserRespDto instance) =>
    <String, dynamic>{'id': ?instance.id, 'userId': ?instance.userId};
