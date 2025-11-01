# soi_api.api.FriendAPIApi

## Load the API package
```dart
import 'package:soi_api/api.dart';
```

All URIs are relative to *http://localhost:8080*

Method | HTTP request | Description
------------- | ------------- | -------------
[**create**](FriendAPIApi.md#create) | **POST** /friend/create | 친구 추가
[**update**](FriendAPIApi.md#update) | **POST** /friend/update | 친구 상태 업데이트


# **create**
> ApiResponseDtoFriendRespDto create(friendReqDto)

친구 추가

사용자 id를 통해 친구추가를 합니다.

### Example
```dart
import 'package:soi_api/api.dart';

final api = SoiApi().getFriendAPIApi();
final FriendReqDto friendReqDto = ; // FriendReqDto | 

try {
    final response = api.create(friendReqDto);
    print(response);
} catch on DioException (e) {
    print('Exception when calling FriendAPIApi->create: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **friendReqDto** | [**FriendReqDto**](FriendReqDto.md)|  | 

### Return type

[**ApiResponseDtoFriendRespDto**](ApiResponseDtoFriendRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **update**
> ApiResponseDtoFriendRespDto update(friendUpdateRespDto)

친구 상태 업데이트

친구 관계 id, 상태 : ACCEPTED, BLOCKED, CANCELLED 를 받아 상태를 업데이트합니다.

### Example
```dart
import 'package:soi_api/api.dart';

final api = SoiApi().getFriendAPIApi();
final FriendUpdateRespDto friendUpdateRespDto = ; // FriendUpdateRespDto | 

try {
    final response = api.update(friendUpdateRespDto);
    print(response);
} catch on DioException (e) {
    print('Exception when calling FriendAPIApi->update: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **friendUpdateRespDto** | [**FriendUpdateRespDto**](FriendUpdateRespDto.md)|  | 

### Return type

[**ApiResponseDtoFriendRespDto**](ApiResponseDtoFriendRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

