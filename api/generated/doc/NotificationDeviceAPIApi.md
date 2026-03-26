# soi_api_client.api.NotificationDeviceAPIApi

## Load the API package
```dart
import 'package:soi_api_client/api.dart';
```

All URIs are relative to *https://newdawnsoi.site*

Method | HTTP request | Description
------------- | ------------- | -------------
[**delete**](NotificationDeviceAPIApi.md#delete) | **POST** /notification/device-token/delete | FCM 토큰 삭제
[**register**](NotificationDeviceAPIApi.md#register) | **POST** /notification/device-token/register | FCM 토큰 등록


# **delete**
> ApiResponseDtoBoolean delete(notificationDeleteTokenReqDto)

FCM 토큰 삭제

로그아웃 또는 토큰 만료 시 FCM 토큰을 비활성화합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = NotificationDeviceAPIApi();
final notificationDeleteTokenReqDto = NotificationDeleteTokenReqDto(); // NotificationDeleteTokenReqDto | 

try {
    final result = api_instance.delete(notificationDeleteTokenReqDto);
    print(result);
} catch (e) {
    print('Exception when calling NotificationDeviceAPIApi->delete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **notificationDeleteTokenReqDto** | [**NotificationDeleteTokenReqDto**](NotificationDeleteTokenReqDto.md)|  | 

### Return type

[**ApiResponseDtoBoolean**](ApiResponseDtoBoolean.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **register**
> ApiResponseDtoBoolean register(notificationRegisterTokenReqDto)

FCM 토큰 등록

로그인 또는 앱 시작 시 발급된 FCM 토큰을 등록합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = NotificationDeviceAPIApi();
final notificationRegisterTokenReqDto = NotificationRegisterTokenReqDto(); // NotificationRegisterTokenReqDto | 

try {
    final result = api_instance.register(notificationRegisterTokenReqDto);
    print(result);
} catch (e) {
    print('Exception when calling NotificationDeviceAPIApi->register: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **notificationRegisterTokenReqDto** | [**NotificationRegisterTokenReqDto**](NotificationRegisterTokenReqDto.md)|  | 

### Return type

[**ApiResponseDtoBoolean**](ApiResponseDtoBoolean.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

