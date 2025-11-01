//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'api_response_dto_boolean.g.dart';


@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ApiResponseDtoBoolean {
  /// Returns a new [ApiResponseDtoBoolean] instance.
  ApiResponseDtoBoolean({

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


  final bool? data;



  @JsonKey(
    
    name: r'message',
    required: false,
    includeIfNull: false,
  )


  final String? message;





    @override
    bool operator ==(Object other) => identical(this, other) || other is ApiResponseDtoBoolean &&
      other.success == success &&
      other.data == data &&
      other.message == message;

    @override
    int get hashCode =>
        success.hashCode +
        data.hashCode +
        message.hashCode;

  factory ApiResponseDtoBoolean.fromJson(Map<String, dynamic> json) => _$ApiResponseDtoBooleanFromJson(json);

  Map<String, dynamic> toJson() => _$ApiResponseDtoBooleanToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }

}

