//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class NotificationRegisterTokenReqDto {
  /// Returns a new [NotificationRegisterTokenReqDto] instance.
  NotificationRegisterTokenReqDto({
    this.token,
    this.platform,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? token;

  NotificationRegisterTokenReqDtoPlatformEnum? platform;

  @override
  bool operator ==(Object other) => identical(this, other) || other is NotificationRegisterTokenReqDto &&
    other.token == token &&
    other.platform == platform;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (token == null ? 0 : token!.hashCode) +
    (platform == null ? 0 : platform!.hashCode);

  @override
  String toString() => 'NotificationRegisterTokenReqDto[token=$token, platform=$platform]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.token != null) {
      json[r'token'] = this.token;
    } else {
      json[r'token'] = null;
    }
    if (this.platform != null) {
      json[r'platform'] = this.platform;
    } else {
      json[r'platform'] = null;
    }
    return json;
  }

  /// Returns a new [NotificationRegisterTokenReqDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static NotificationRegisterTokenReqDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "NotificationRegisterTokenReqDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "NotificationRegisterTokenReqDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return NotificationRegisterTokenReqDto(
        token: mapValueOfType<String>(json, r'token'),
        platform: NotificationRegisterTokenReqDtoPlatformEnum.fromJson(json[r'platform']),
      );
    }
    return null;
  }

  static List<NotificationRegisterTokenReqDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <NotificationRegisterTokenReqDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = NotificationRegisterTokenReqDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, NotificationRegisterTokenReqDto> mapFromJson(dynamic json) {
    final map = <String, NotificationRegisterTokenReqDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = NotificationRegisterTokenReqDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of NotificationRegisterTokenReqDto-objects as value to a dart map
  static Map<String, List<NotificationRegisterTokenReqDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<NotificationRegisterTokenReqDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = NotificationRegisterTokenReqDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}


class NotificationRegisterTokenReqDtoPlatformEnum {
  /// Instantiate a new enum with the provided [value].
  const NotificationRegisterTokenReqDtoPlatformEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const ANDROID = NotificationRegisterTokenReqDtoPlatformEnum._(r'ANDROID');
  static const IOS = NotificationRegisterTokenReqDtoPlatformEnum._(r'IOS');
  static const WEB = NotificationRegisterTokenReqDtoPlatformEnum._(r'WEB');

  /// List of all possible values in this [enum][NotificationRegisterTokenReqDtoPlatformEnum].
  static const values = <NotificationRegisterTokenReqDtoPlatformEnum>[
    ANDROID,
    IOS,
    WEB,
  ];

  static NotificationRegisterTokenReqDtoPlatformEnum? fromJson(dynamic value) => NotificationRegisterTokenReqDtoPlatformEnumTypeTransformer().decode(value);

  static List<NotificationRegisterTokenReqDtoPlatformEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <NotificationRegisterTokenReqDtoPlatformEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = NotificationRegisterTokenReqDtoPlatformEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [NotificationRegisterTokenReqDtoPlatformEnum] to String,
/// and [decode] dynamic data back to [NotificationRegisterTokenReqDtoPlatformEnum].
class NotificationRegisterTokenReqDtoPlatformEnumTypeTransformer {
  factory NotificationRegisterTokenReqDtoPlatformEnumTypeTransformer() => _instance ??= const NotificationRegisterTokenReqDtoPlatformEnumTypeTransformer._();

  const NotificationRegisterTokenReqDtoPlatformEnumTypeTransformer._();

  String encode(NotificationRegisterTokenReqDtoPlatformEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a NotificationRegisterTokenReqDtoPlatformEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  NotificationRegisterTokenReqDtoPlatformEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'ANDROID': return NotificationRegisterTokenReqDtoPlatformEnum.ANDROID;
        case r'IOS': return NotificationRegisterTokenReqDtoPlatformEnum.IOS;
        case r'WEB': return NotificationRegisterTokenReqDtoPlatformEnum.WEB;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [NotificationRegisterTokenReqDtoPlatformEnumTypeTransformer] instance.
  static NotificationRegisterTokenReqDtoPlatformEnumTypeTransformer? _instance;
}


