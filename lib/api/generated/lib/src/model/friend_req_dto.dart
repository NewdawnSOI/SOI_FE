//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'friend_req_dto.g.dart';


@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FriendReqDto {
  /// Returns a new [FriendReqDto] instance.
  FriendReqDto({

     this.requesterId,

     this.receiverId,
  });

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





    @override
    bool operator ==(Object other) => identical(this, other) || other is FriendReqDto &&
      other.requesterId == requesterId &&
      other.receiverId == receiverId;

    @override
    int get hashCode =>
        requesterId.hashCode +
        receiverId.hashCode;

  factory FriendReqDto.fromJson(Map<String, dynamic> json) => _$FriendReqDtoFromJson(json);

  Map<String, dynamic> toJson() => _$FriendReqDtoToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }

}

