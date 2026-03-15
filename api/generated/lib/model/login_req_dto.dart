//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class LoginReqDto {
  /// Returns a new [LoginReqDto] instance.
  LoginReqDto({
    required this.nickname,
    required this.phoneNum,
  });

  String nickname;

  String phoneNum;

  @override
  bool operator ==(Object other) => identical(this, other) || other is LoginReqDto &&
    other.nickname == nickname &&
    other.phoneNum == phoneNum;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (nickname.hashCode) +
    (phoneNum.hashCode);

  @override
  String toString() => 'LoginReqDto[nickname=$nickname, phoneNum=$phoneNum]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'nickname'] = this.nickname;
      json[r'phoneNum'] = this.phoneNum;
    return json;
  }

  /// Returns a new [LoginReqDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static LoginReqDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "LoginReqDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "LoginReqDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return LoginReqDto(
        nickname: mapValueOfType<String>(json, r'nickname')!,
        phoneNum: mapValueOfType<String>(json, r'phoneNum')!,
      );
    }
    return null;
  }

  static List<LoginReqDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <LoginReqDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = LoginReqDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, LoginReqDto> mapFromJson(dynamic json) {
    final map = <String, LoginReqDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = LoginReqDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of LoginReqDto-objects as value to a dart map
  static Map<String, List<LoginReqDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<LoginReqDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = LoginReqDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'nickname',
    'phoneNum',
  };
}

