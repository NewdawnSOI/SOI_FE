import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:soi/api/services/media_service.dart';
import 'package:soi_api_client/api.dart';

class _FakeMediaApi extends APIApi {
  _FakeMediaApi({this.onUpload});

  final Future<ApiResponseDtoListString?> Function(
    List<String>,
    List<String>,
    int,
    int,
    List<http.MultipartFile>,
  )?
  onUpload;

  @override
  Future<ApiResponseDtoListString?> uploadMedia(
    List<String> types,
    List<String> usageTypes,
    int refId,
    int usageCount,
    List<http.MultipartFile> files,
  ) async {
    final handler = onUpload;
    if (handler == null) {
      throw UnimplementedError('onUpload is not configured');
    }
    return handler(types, usageTypes, refId, usageCount, files);
  }
}

void main() {
  group('MediaService', () {
    test('uploadCommentAudio uses comment usage type', () async {
      List<String>? capturedUsageTypes;
      final service = MediaService(
        mediaApi: _FakeMediaApi(
          onUpload: (types, usageTypes, refId, usageCount, files) async {
            capturedUsageTypes = usageTypes;
            expect(types, ['AUDIO']);
            expect(refId, 42);
            expect(usageCount, 1);
            expect(files, hasLength(1));
            return ApiResponseDtoListString(
              success: true,
              data: const ['comment-audio-key'],
            );
          },
        ),
      );

      final file = http.MultipartFile.fromBytes('files', [
        1,
        2,
        3,
      ], filename: 'audio.m4a');

      final result = await service.uploadCommentAudio(
        file: file,
        userId: 7,
        postId: 42,
      );

      expect(result, 'comment-audio-key');
      expect(capturedUsageTypes, ['COMMENT']);
    });
  });
}
