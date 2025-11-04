# soi_api_client.api.FriendAPIApi

## Load the API package
```dart
import 'package:soi_api_client/api.dart';
```

All URIs are relative to *https://newdawnsoi.site*

Method | HTTP request | Description
------------- | ------------- | -------------
[**blockFriend**](FriendAPIApi.md#blockfriend) | **POST** /friend/block | 친구 차단
[**create**](FriendAPIApi.md#create) | **POST** /friend/create | 친구 추가
[**deleteFriend**](FriendAPIApi.md#deletefriend) | **POST** /friend/get-all | 친구 삭제
[**getAllFriend**](FriendAPIApi.md#getallfriend) | **GET** /friend/get-all | 모든 친구 조회
[**unBlockFriend**](FriendAPIApi.md#unblockfriend) | **POST** /friend/unblock | 친구 차단 해제
[**update**](FriendAPIApi.md#update) | **POST** /friend/update | 친구 상태 업데이트


# **blockFriend**
> ApiResponseDtoBoolean blockFriend(friendReqDto)

친구 차단

차단 요청을 한 사용자의 id : requesterId에 차단을 당하는 사용자의 id : receiverId에 담아서 요청

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = FriendAPIApi();
final friendReqDto = FriendReqDto(); // FriendReqDto | 

try {
    final result = api_instance.blockFriend(friendReqDto);
    print(result);
} catch (e) {
    print('Exception when calling FriendAPIApi->blockFriend: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **friendReqDto** | [**FriendReqDto**](FriendReqDto.md)|  | 

### Return type

[**ApiResponseDtoBoolean**](ApiResponseDtoBoolean.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **create**
> ApiResponseDtoFriendRespDto create(friendReqDto)

친구 추가

사용자 id를 통해 친구추가를 합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = FriendAPIApi();
final friendReqDto = FriendReqDto(); // FriendReqDto | 

try {
    final result = api_instance.create(friendReqDto);
    print(result);
} catch (e) {
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

# **deleteFriend**
> ApiResponseDtoBoolean deleteFriend(friendReqDto)

친구 삭제

삭제 요청을 한 사용자의 id : requesterId에 삭제를 당하는 사용자의 id : receiverId에 담아서 요청 만약 삭제후, 서로가 삭제된 관계면 친구 관계 컬럼을 삭제함

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = FriendAPIApi();
final friendReqDto = FriendReqDto(); // FriendReqDto | 

try {
    final result = api_instance.deleteFriend(friendReqDto);
    print(result);
} catch (e) {
    print('Exception when calling FriendAPIApi->deleteFriend: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **friendReqDto** | [**FriendReqDto**](FriendReqDto.md)|  | 

### Return type

[**ApiResponseDtoBoolean**](ApiResponseDtoBoolean.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getAllFriend**
> ApiResponseDtoListUserFindRespDto getAllFriend(userId)

모든 친구 조회

유저의 id (user_id 말고 그냥 id)를 통해 모든 친구를 조회합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = FriendAPIApi();
final userId = 789; // int | 

try {
    final result = api_instance.getAllFriend(userId);
    print(result);
} catch (e) {
    print('Exception when calling FriendAPIApi->getAllFriend: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **int**|  | 

### Return type

[**ApiResponseDtoListUserFindRespDto**](ApiResponseDtoListUserFindRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **unBlockFriend**
> ApiResponseDtoBoolean unBlockFriend(friendReqDto)

친구 차단 해제

차단 해제 요청을 한 사용자의 id : requesterId에 차단 해제를 당하는 사용자의 id : receiverId에 담아서 요청차단 해제후에는 친구 관계가 완전 초기화 (삭제) 됩니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = FriendAPIApi();
final friendReqDto = FriendReqDto(); // FriendReqDto | 

try {
    final result = api_instance.unBlockFriend(friendReqDto);
    print(result);
} catch (e) {
    print('Exception when calling FriendAPIApi->unBlockFriend: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **friendReqDto** | [**FriendReqDto**](FriendReqDto.md)|  | 

### Return type

[**ApiResponseDtoBoolean**](ApiResponseDtoBoolean.md)

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
import 'package:soi_api_client/api.dart';

final api_instance = FriendAPIApi();
final friendUpdateRespDto = FriendUpdateRespDto(); // FriendUpdateRespDto | 

try {
    final result = api_instance.update(friendUpdateRespDto);
    print(result);
} catch (e) {
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

