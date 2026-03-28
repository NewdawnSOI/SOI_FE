import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:soi/utils/video_thumbnail_cache.dart';

import '../support/fake_media_processing_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoThumbnailCache', () {
    tearDown(() {
      VideoThumbnailCache.debugReset();
    });

    test(
      'dedupes same-key thumbnail generation while a request is in flight',
      () async {
        final cacheDir = await Directory.systemTemp.createTemp(
          'video_thumbnail_cache_test',
        );
        addTearDown(() async {
          if (await cacheDir.exists()) {
            await cacheDir.delete(recursive: true);
          }
        });

        final completer = Completer<Uint8List?>();
        final backend = FakeMediaProcessingBackend(
          onGenerateThumbnailData:
              ({
                required videoPath,
                required format,
                required maxWidth,
                required maxHeight,
                required quality,
              }) {
                return completer.future;
              },
        );

        VideoThumbnailCache.debugOverrideBackend(backend);
        VideoThumbnailCache.debugPrimeCacheDirectory(cacheDir.path);

        final futureA = VideoThumbnailCache.getThumbnail(
          videoUrl: 'https://example.com/video.mp4',
          cacheKey: 'same-key',
        );
        final futureB = VideoThumbnailCache.getThumbnail(
          videoUrl: 'https://example.com/video.mp4',
          cacheKey: 'same-key',
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(backend.generateThumbnailDataCalls, 1);

        final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
        completer.complete(bytes);

        final results = await Future.wait(<Future<Uint8List?>>[
          futureA,
          futureB,
        ]);
        expect(results[0], bytes);
        expect(results[1], bytes);

        final cached = await VideoThumbnailCache.getThumbnail(
          videoUrl: 'https://example.com/video.mp4',
          cacheKey: 'same-key',
        );
        expect(cached, bytes);
        expect(backend.generateThumbnailDataCalls, 1);
      },
    );
  });
}
