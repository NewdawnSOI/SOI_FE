/// 미디어 API 서비스
/// APIApi를 래핑하여 Flutter에서 사용하기 쉽게 만든 서비스
library;

import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:soi_api/api.dart' as api;
import '../common/api_client.dart';
import '../common/api_result.dart';
import '../common/api_exception.dart';

class MediaService {
  late final api.APIApi _mediaApi;

  MediaService() {
    _mediaApi = api.APIApi(SoiApiClient().client);
  }

  /// S3 Presigned URL 요청
  ///
  /// [s3Key] DB에 저장된 S3 key
  /// Returns: 1시간 유효한 접근 URL
  Future<ApiResult<String>> getPresignedUrl(String s3Key) async {
    try {
      developer.log('🔗 Presigned URL 요청: $s3Key', name: 'MediaService');

      final response = await _mediaApi.getPresignedUrl(s3Key);

      if (response?.data == null) {
        return Failure(ApiException.serverError('Presigned URL 요청에 실패했습니다'));
      }

      developer.log('✅ Presigned URL 요청 성공', name: 'MediaService');
      return Success(response!.data!);
    } on api.ApiException catch (e) {
      developer.log(
        '❌ Presigned URL 요청 실패: ${e.message}',
        name: 'MediaService',
      );
      return Failure(ApiException.fromStatusCode(e.code, e.message));
    } catch (e) {
      developer.log('❌ Presigned URL 요청 오류: $e', name: 'MediaService');
      return Failure(ApiException.networkError());
    }
  }

  /// 미디어 파일 업로드
  ///
  /// [files] 업로드할 파일 리스트
  /// [types] 파일 타입 (여러개의 경우 ,로 구분)
  /// [id] 사용자 또는 엔티티 ID
  /// Returns: 업로드된 파일의 S3 key 리스트
  Future<ApiResult<List<String>>> uploadMedia({
    required List<File> files,
    required String types,
    required int id,
  }) async {
    try {
      developer.log('📤 미디어 업로드: ${files.length}개 파일', name: 'MediaService');

      // File을 MultipartFile로 변환
      final multipartFiles = <http.MultipartFile>[];
      for (var file in files) {
        final multipartFile = await http.MultipartFile.fromPath(
          'files',
          file.path,
        );
        multipartFiles.add(multipartFile);
      }

      final response = await _mediaApi.uploadMedia(types, id, multipartFiles);

      if (response?.data == null) {
        return Failure(ApiException.serverError('미디어 업로드에 실패했습니다'));
      }

      final s3Keys = response?.data;
      developer.log('✅ 미디어 업로드 성공: ${s3Keys!.length}개', name: 'MediaService');
      return Success(s3Keys);
    } on api.ApiException catch (e) {
      developer.log('❌ 미디어 업로드 실패: ${e.message}', name: 'MediaService');
      return Failure(ApiException.fromStatusCode(e.code, e.message));
    } catch (e) {
      developer.log('❌ 미디어 업로드 오류: $e', name: 'MediaService');
      return Failure(ApiException.networkError());
    }
  }

  /// 단일 파일 업로드 헬퍼
  ///
  /// [file] 업로드할 파일
  /// [type] 파일 타입
  /// [id] 사용자 또는 엔티티 ID
  Future<ApiResult<String>> uploadSingleMedia({
    required File file,
    required String type,
    required int id,
  }) async {
    final result = await uploadMedia(files: [file], types: type, id: id);

    return result.when(
      success: (keys) {
        if (keys.isEmpty) {
          return Failure(ApiException.serverError('업로드된 파일이 없습니다'));
        }
        return Success(keys.first);
      },
      failure: (exception) => Failure(exception),
    );
  }
}
