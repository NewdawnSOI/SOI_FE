// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_create_req_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserCreateReqDto _$UserCreateReqDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('UserCreateReqDto', json, ($checkedConvert) {
      final val = UserCreateReqDto(
        name: $checkedConvert('name', (v) => v as String?),
        userId: $checkedConvert('userId', (v) => v as String?),
        phone: $checkedConvert('phone', (v) => v as String?),
        birthDate: $checkedConvert('birth_date', (v) => v as String?),
        profileImage: $checkedConvert('profileImage', (v) => v as String?),
        serviceAgreed: $checkedConvert('serviceAgreed', (v) => v as bool?),
        privacyPolicyAgreed: $checkedConvert(
          'privacyPolicyAgreed',
          (v) => v as bool?,
        ),
        marketingAgreed: $checkedConvert('marketingAgreed', (v) => v as bool?),
      );
      return val;
    }, fieldKeyMap: const {'birthDate': 'birth_date'});

Map<String, dynamic> _$UserCreateReqDtoToJson(UserCreateReqDto instance) =>
    <String, dynamic>{
      'name': ?instance.name,
      'userId': ?instance.userId,
      'phone': ?instance.phone,
      'birth_date': ?instance.birthDate,
      'profileImage': ?instance.profileImage,
      'serviceAgreed': ?instance.serviceAgreed,
      'privacyPolicyAgreed': ?instance.privacyPolicyAgreed,
      'marketingAgreed': ?instance.marketingAgreed,
    };
