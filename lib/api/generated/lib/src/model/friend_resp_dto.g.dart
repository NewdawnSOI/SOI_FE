// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friend_resp_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FriendRespDto _$FriendRespDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('FriendRespDto', json, ($checkedConvert) {
      final val = FriendRespDto(
        id: $checkedConvert('id', (v) => (v as num?)?.toInt()),
        requesterId: $checkedConvert(
          'requesterId',
          (v) => (v as num?)?.toInt(),
        ),
        receiverId: $checkedConvert('receiverId', (v) => (v as num?)?.toInt()),
        notificationId: $checkedConvert(
          'notificationId',
          (v) => (v as num?)?.toInt(),
        ),
        status: $checkedConvert(
          'status',
          (v) => $enumDecodeNullable(_$FriendRespDtoStatusEnumEnumMap, v),
        ),
        createdAt: $checkedConvert(
          'createdAt',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$FriendRespDtoToJson(FriendRespDto instance) =>
    <String, dynamic>{
      'id': ?instance.id,
      'requesterId': ?instance.requesterId,
      'receiverId': ?instance.receiverId,
      'notificationId': ?instance.notificationId,
      'status': ?_$FriendRespDtoStatusEnumEnumMap[instance.status],
      'createdAt': ?instance.createdAt?.toIso8601String(),
    };

const _$FriendRespDtoStatusEnumEnumMap = {
  FriendRespDtoStatusEnum.PENDING: 'PENDING',
  FriendRespDtoStatusEnum.ACCEPTED: 'ACCEPTED',
  FriendRespDtoStatusEnum.BLOCKED: 'BLOCKED',
  FriendRespDtoStatusEnum.CANCELLED: 'CANCELLED',
};
