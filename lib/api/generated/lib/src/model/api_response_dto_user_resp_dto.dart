//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:soi_api/src/model/user_resp_dto.dart';
import 'package:json_annotation/json_annotation.dart';

part 'api_response_dto_user_resp_dto.g.dart';


@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ApiResponseDtoUserRespDto {
  /// Returns a new [ApiResponseDtoUserRespDto] instance.
  ApiResponseDtoUserRespDto({

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


  final UserRespDto? data;



  @JsonKey(
    
    name: r'message',
    required: false,
    includeIfNull: false,
  )


  final String? message;





    @override
    bool operator ==(Object other) => identical(this, other) || other is ApiResponseDtoUserRespDto &&
      other.success == success &&
      other.data == data &&
      other.message == message;

    @override
    int get hashCode =>
        success.hashCode +
        data.hashCode +
        message.hashCode;

  factory ApiResponseDtoUserRespDto.fromJson(Map<String, dynamic> json) => _$ApiResponseDtoUserRespDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ApiResponseDtoUserRespDtoToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }

}

