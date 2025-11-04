# soi_api_client.api.APIApi

## Load the API package
```dart
import 'package:soi_api_client/api.dart';
```

All URIs are relative to *https://newdawnsoi.site*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getPresignedUrl**](APIApi.md#getpresignedurl) | **GET** /media/get-url | Presigned URL 요청
[**uploadMedia**](APIApi.md#uploadmedia) | **POST** /media/upload | 미디어 업로드


# **getPresignedUrl**
> ApiResponseDtoString getPresignedUrl(key)

Presigned URL 요청

DB에 저장된 S3 key를 입력하면 1시간 유효한 접근 URL을 반환합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = APIApi();
final key = key_example; // String | 

try {
    final result = api_instance.getPresignedUrl(key);
    print(result);
} catch (e) {
    print('Exception when calling APIApi->getPresignedUrl: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **key** | **String**|  | 

### Return type

[**ApiResponseDtoString**](ApiResponseDtoString.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **uploadMedia**
> ApiResponseDtoListString uploadMedia(types, id, files)

미디어 업로드

단일, 여러개의 파일을 올릴 수 있습니다. 여러개의 파일 업로드시 , 로 구분해서 type을 명시합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = APIApi();
final types = types_example; // String | 
final id = 789; // int | 
final files = [/path/to/file.txt]; // List<MultipartFile> | 

try {
    final result = api_instance.uploadMedia(types, id, files);
    print(result);
} catch (e) {
    print('Exception when calling APIApi->uploadMedia: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **types** | **String**|  | 
 **id** | **int**|  | 
 **files** | [**List<MultipartFile>**](MultipartFile.md)|  | 

### Return type

[**ApiResponseDtoListString**](ApiResponseDtoListString.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: multipart/form-data
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

