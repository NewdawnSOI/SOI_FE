// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friend_update_resp_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FriendUpdateRespDto _$FriendUpdateRespDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('FriendUpdateRespDto', json, ($checkedConvert) {
      final val = FriendUpdateRespDto(
        id: $checkedConvert('id', (v) => (v as num?)?.toInt()),
        status: $checkedConvert(
          'status',
          (v) => $enumDecodeNullable(_$FriendUpdateRespDtoStatusEnumEnumMap, v),
        ),
      );
      return val;
    });

Map<String, dynamic> _$FriendUpdateRespDtoToJson(
  FriendUpdateRespDto instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'status': ?_$FriendUpdateRespDtoStatusEnumEnumMap[instance.status],
};

const _$FriendUpdateRespDtoStatusEnumEnumMap = {
  FriendUpdateRespDtoStatusEnum.PENDING: 'PENDING',
  FriendUpdateRespDtoStatusEnum.ACCEPTED: 'ACCEPTED',
  FriendUpdateRespDtoStatusEnum.BLOCKED: 'BLOCKED',
  FriendUpdateRespDtoStatusEnum.CANCELLED: 'CANCELLED',
};
