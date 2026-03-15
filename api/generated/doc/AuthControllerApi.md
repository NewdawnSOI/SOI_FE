# soi_api_client.api.AuthControllerApi

## Load the API package
```dart
import 'package:soi_api_client/api.dart';
```

All URIs are relative to *https://newdawnsoi.site*

Method | HTTP request | Description
------------- | ------------- | -------------
[**login**](AuthControllerApi.md#login) | **POST** /auth/login | 


# **login**
> LoginRespDto login(loginReqDto)



### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = AuthControllerApi();
final loginReqDto = LoginReqDto(); // LoginReqDto | 

try {
    final result = api_instance.login(loginReqDto);
    print(result);
} catch (e) {
    print('Exception when calling AuthControllerApi->login: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **loginReqDto** | [**LoginReqDto**](LoginReqDto.md)|  | 

### Return type

[**LoginRespDto**](LoginRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

