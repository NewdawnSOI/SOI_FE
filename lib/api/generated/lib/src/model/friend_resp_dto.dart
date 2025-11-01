//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'friend_resp_dto.g.dart';


@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FriendRespDto {
  /// Returns a new [FriendRespDto] instance.
  FriendRespDto({

     this.id,

     this.requesterId,

     this.receiverId,

     this.notificationId,

     this.status,

     this.createdAt,
  });

  @JsonKey(
    
    name: r'id',
    required: false,
    includeIfNull: false,
  )


  final int? id;



  @JsonKey(
    
    name: r'requesterId',
    required: false,
    includeIfNull: false,
  )


  final int? requesterId;



  @JsonKey(
    
    name: r'receiverId',
    required: false,
    includeIfNull: false,
  )


  final int? receiverId;



  @JsonKey(
    
    name: r'notificationId',
    required: false,
    includeIfNull: false,
  )


  final int? notificationId;



  @JsonKey(
    
    name: r'status',
    required: false,
    includeIfNull: false,
  )


  final FriendRespDtoStatusEnum? status;



  @JsonKey(
    
    name: r'createdAt',
    required: false,
    includeIfNull: false,
  )


  final DateTime? createdAt;





    @override
    bool operator ==(Object other) => identical(this, other) || other is FriendRespDto &&
      other.id == id &&
      other.requesterId == requesterId &&
      other.receiverId == receiverId &&
      other.notificationId == notificationId &&
      other.status == status &&
      other.createdAt == createdAt;

    @override
    int get hashCode =>
        id.hashCode +
        requesterId.hashCode +
        receiverId.hashCode +
        notificationId.hashCode +
        status.hashCode +
        createdAt.hashCode;

  factory FriendRespDto.fromJson(Map<String, dynamic> json) => _$FriendRespDtoFromJson(json);

  Map<String, dynamic> toJson() => _$FriendRespDtoToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }

}


enum FriendRespDtoStatusEnum {
@JsonValue(r'PENDING')
PENDING(r'PENDING'),
@JsonValue(r'ACCEPTED')
ACCEPTED(r'ACCEPTED'),
@JsonValue(r'BLOCKED')
BLOCKED(r'BLOCKED'),
@JsonValue(r'CANCELLED')
CANCELLED(r'CANCELLED');

const FriendRespDtoStatusEnum(this.value);

final String value;

@override
String toString() => value;
}


