//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'user_create_req_dto.g.dart';


@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class UserCreateReqDto {
  /// Returns a new [UserCreateReqDto] instance.
  UserCreateReqDto({

     this.name,

     this.userId,

     this.phone,

     this.birthDate,

     this.profileImage,

     this.serviceAgreed,

     this.privacyPolicyAgreed,

     this.marketingAgreed,
  });

  @JsonKey(
    
    name: r'name',
    required: false,
    includeIfNull: false,
  )


  final String? name;



  @JsonKey(
    
    name: r'userId',
    required: false,
    includeIfNull: false,
  )


  final String? userId;



  @JsonKey(
    
    name: r'phone',
    required: false,
    includeIfNull: false,
  )


  final String? phone;



  @JsonKey(
    
    name: r'birth_date',
    required: false,
    includeIfNull: false,
  )


  final String? birthDate;



  @JsonKey(
    
    name: r'profileImage',
    required: false,
    includeIfNull: false,
  )


  final String? profileImage;



  @JsonKey(
    
    name: r'serviceAgreed',
    required: false,
    includeIfNull: false,
  )


  final bool? serviceAgreed;



  @JsonKey(
    
    name: r'privacyPolicyAgreed',
    required: false,
    includeIfNull: false,
  )


  final bool? privacyPolicyAgreed;



  @JsonKey(
    
    name: r'marketingAgreed',
    required: false,
    includeIfNull: false,
  )


  final bool? marketingAgreed;





    @override
    bool operator ==(Object other) => identical(this, other) || other is UserCreateReqDto &&
      other.name == name &&
      other.userId == userId &&
      other.phone == phone &&
      other.birthDate == birthDate &&
      other.profileImage == profileImage &&
      other.serviceAgreed == serviceAgreed &&
      other.privacyPolicyAgreed == privacyPolicyAgreed &&
      other.marketingAgreed == marketingAgreed;

    @override
    int get hashCode =>
        name.hashCode +
        userId.hashCode +
        phone.hashCode +
        birthDate.hashCode +
        profileImage.hashCode +
        serviceAgreed.hashCode +
        privacyPolicyAgreed.hashCode +
        marketingAgreed.hashCode;

  factory UserCreateReqDto.fromJson(Map<String, dynamic> json) => _$UserCreateReqDtoFromJson(json);

  Map<String, dynamic> toJson() => _$UserCreateReqDtoToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }

}

