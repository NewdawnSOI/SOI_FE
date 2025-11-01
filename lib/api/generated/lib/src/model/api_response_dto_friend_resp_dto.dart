//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:soi_api/src/model/friend_resp_dto.dart';
import 'package:json_annotation/json_annotation.dart';

part 'api_response_dto_friend_resp_dto.g.dart';


@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ApiResponseDtoFriendRespDto {
  /// Returns a new [ApiResponseDtoFriendRespDto] instance.
  ApiResponseDtoFriendRespDto({

     this.success,

     this.data,

     this.message,
  });

  @JsonKey(
    
    name: r'success',
    required: false,
    includeIfNull: false,
  )


  final bool? success;



  @JsonKey(
    
    name: r'data',
    required: false,
    includeIfNull: false,
  )


  final FriendRespDto? data;



  @JsonKey(
    
    name: r'message',
    required: false,
    includeIfNull: false,
  )


  final String? message;





    @override
    bool operator ==(Object other) => identical(this, other) || other is ApiResponseDtoFriendRespDto &&
      other.success == success &&
      other.data == data &&
      other.message == message;

    @override
    int get hashCode =>
        success.hashCode +
        data.hashCode +
        message.hashCode;

  factory ApiResponseDtoFriendRespDto.fromJson(Map<String, dynamic> json) => _$ApiResponseDtoFriendRespDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ApiResponseDtoFriendRespDtoToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }

}

