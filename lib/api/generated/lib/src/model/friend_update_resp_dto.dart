//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'friend_update_resp_dto.g.dart';


@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FriendUpdateRespDto {
  /// Returns a new [FriendUpdateRespDto] instance.
  FriendUpdateRespDto({

     this.id,

     this.status,
  });

  @JsonKey(
    
    name: r'id',
    required: false,
    includeIfNull: false,
  )


  final int? id;



  @JsonKey(
    
    name: r'status',
    required: false,
    includeIfNull: false,
  )


  final FriendUpdateRespDtoStatusEnum? status;





    @override
    bool operator ==(Object other) => identical(this, other) || other is FriendUpdateRespDto &&
      other.id == id &&
      other.status == status;

    @override
    int get hashCode =>
        id.hashCode +
        status.hashCode;

  factory FriendUpdateRespDto.fromJson(Map<String, dynamic> json) => _$FriendUpdateRespDtoFromJson(json);

  Map<String, dynamic> toJson() => _$FriendUpdateRespDtoToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }

}


enum FriendUpdateRespDtoStatusEnum {
@JsonValue(r'PENDING')
PENDING(r'PENDING'),
@JsonValue(r'ACCEPTED')
ACCEPTED(r'ACCEPTED'),
@JsonValue(r'BLOCKED')
BLOCKED(r'BLOCKED'),
@JsonValue(r'CANCELLED')
CANCELLED(r'CANCELLED');

const FriendUpdateRespDtoStatusEnum(this.value);

final String value;

@override
String toString() => value;
}


