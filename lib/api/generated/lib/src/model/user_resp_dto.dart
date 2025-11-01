//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'user_resp_dto.g.dart';


@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class UserRespDto {
  /// Returns a new [UserRespDto] instance.
  UserRespDto({

     this.id,

     this.userId,
  });

  @JsonKey(
    
    name: r'id',
    required: false,
    includeIfNull: false,
  )


  final int? id;



  @JsonKey(
    
    name: r'userId',
    required: false,
    includeIfNull: false,
  )


  final String? userId;





    @override
    bool operator ==(Object other) => identical(this, other) || other is UserRespDto &&
      other.id == id &&
      other.userId == userId;

    @override
    int get hashCode =>
        id.hashCode +
        userId.hashCode;

  factory UserRespDto.fromJson(Map<String, dynamic> json) => _$UserRespDtoFromJson(json);

  Map<String, dynamic> toJson() => _$UserRespDtoToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }

}

