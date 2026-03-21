import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:soi/api/services/media_service.dart';
import 'package:soi_api_client/api.dart';

class _FakeMediaApi extends APIApi {
  _FakeMediaApi({this.onUpload, this.onGetPresignedUrl});

  final Future<ApiResponseDtoListString?> Function(
    List<String>,
    List<String>,
    int,
    int,
    List<http.MultipartFile>,
  )?
  onUpload;
  final Future<ApiResponseDtoListString?> Function(List<String>)?
  onGetPresignedUrl;

  @override
  Future<ApiResponseDtoListString?> getPresignedUrl(List<String> keys) async {
    final handler = onGetPresignedUrl;
    if (handler == null) {
      throw UnimplementedError('onGetPresignedUrl is not configured');
    }
    return handler(keys);
  }

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
    test(
      'dedupes in-flight getPresignedUrls requests for identical batches',
      () async {
        final completer = Completer<ApiResponseDtoListString?>();
        var callCount = 0;

        final service = MediaService(
          mediaApi: _FakeMediaApi(
            onGetPresignedUrl: (keys) {
              callCount++;
              expect(keys, ['image/a.jpg', 'audio/b.m4a']);
              return completer.future;
            },
          ),
        );

        final first = service.getPresignedUrls(['image/a.jpg', 'audio/b.m4a']);
        final second = service.getPresignedUrls(['image/a.jpg', 'audio/b.m4a']);

        completer.complete(
          ApiResponseDtoListString(
            success: true,
            data: const ['https://cdn.test/a', 'https://cdn.test/b'],
          ),
        );

        final results = await Future.wait([first, second]);

        expect(callCount, 1);
        expect(results[0], ['https://cdn.test/a', 'https://cdn.test/b']);
        expect(results[1], ['https://cdn.test/a', 'https://cdn.test/b']);
      },
    );

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

    test('filesToMultipart preserves file order', () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'media_service_test',
      );
      addTearDown(() => tempDirectory.delete(recursive: true));

      final firstFile = File('${tempDirectory.path}/first.txt')
        ..writeAsBytesSync([1, 2, 3]);
      final secondFile = File('${tempDirectory.path}/second.txt')
        ..writeAsBytesSync([4, 5]);

      final multipartFiles = await MediaService.filesToMultipart([
        firstFile,
        secondFile,
      ]);

      expect(multipartFiles.map((file) => file.filename), [
        'first.txt',
        'second.txt',
      ]);
      expect(multipartFiles.map((file) => file.length), [3, 2]);
    });
  });
}
