// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friend_req_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FriendReqDto _$FriendReqDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('FriendReqDto', json, ($checkedConvert) {
      final val = FriendReqDto(
        requesterId: $checkedConvert(
          'requesterId',
          (v) => (v as num?)?.toInt(),
        ),
        receiverId: $checkedConvert('receiverId', (v) => (v as num?)?.toInt()),
      );
      return val;
    });

Map<String, dynamic> _$FriendReqDtoToJson(FriendReqDto instance) =>
    <String, dynamic>{
      'requesterId': ?instance.requesterId,
      'receiverId': ?instance.receiverId,
    };
