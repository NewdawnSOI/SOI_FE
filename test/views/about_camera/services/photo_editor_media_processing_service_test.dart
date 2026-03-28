import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/media_processing/media_processing_backend.dart';
import 'package:soi/views/about_camera/services/photo_editor_media_processing_service.dart';

import '../../../support/fake_media_processing_backend.dart';

void main() {
  group('PhotoEditorMediaProcessingService', () {
    test('calculateImageAspectRatio uses backend probe metadata', () async {
      final service = PhotoEditorMediaProcessingService(
        mediaProcessingBackend: FakeMediaProcessingBackend(
          onProbeImage: (_) async =>
              const MediaImageProbeResult(width: 1920, height: 1080),
        ),
      );

      final ratio = await service.calculateImageAspectRatio(File('unused.jpg'));

      expect(ratio, closeTo(1920 / 1080, 0.000001));
    });

    test(
      'compressImageIfNeeded returns backend output when it meets size cap',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'photo_editor_media_processing_service_test',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final originalFile = File('${tempDir.path}/original.jpg');
        await originalFile.writeAsBytes(
          Uint8List(1024 * 1024 + 128),
          flush: true,
        );

        final service = PhotoEditorMediaProcessingService(
          mediaProcessingBackend: FakeMediaProcessingBackend(
            onCompressImage:
                ({
                  required inputFile,
                  required outputPath,
                  required quality,
                  required minWidth,
                  required minHeight,
                  required format,
                }) async {
                  final compressedFile = File(outputPath);
                  await compressedFile.writeAsBytes(
                    Uint8List(2048),
                    flush: true,
                  );
                  return compressedFile;
                },
          ),
          temporaryDirectoryProvider: () async => tempDir,
        );

        final result = await service.compressImageIfNeeded(originalFile);

        expect(result.path, isNot(originalFile.path));
        expect(await result.length(), lessThanOrEqualTo(1024 * 1024));
      },
    );

    test('extractVideoThumbnailFile delegates to the shared backend', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'photo_editor_media_thumbnail_test',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final expectedFile = File('${tempDir.path}/thumb.webp');
      await expectedFile.writeAsBytes(<int>[1, 2, 3], flush: true);

      final service = PhotoEditorMediaProcessingService(
        mediaProcessingBackend: FakeMediaProcessingBackend(
          onGenerateThumbnail:
              ({
                required videoPath,
                required outputPath,
                required format,
                required maxWidth,
                required maxHeight,
                required quality,
              }) async {
                expect(videoPath, '/tmp/source.mov');
                expect(outputPath, tempDir.path);
                expect(format, MediaThumbnailFormat.webp);
                return expectedFile;
              },
        ),
        temporaryDirectoryProvider: () async => tempDir,
      );

      final result = await service.extractVideoThumbnailFile('/tmp/source.mov');

      expect(result?.path, expectedFile.path);
    });

    test(
      'encodeWaveformDataAsync keeps CSV compatibility with 6 decimals',
      () async {
        final service = PhotoEditorMediaProcessingService(
          mediaProcessingBackend: FakeMediaProcessingBackend(),
        );

        final encoded = await service.encodeWaveformDataAsync(const <double>[
          0.1234567,
          0.5,
          1,
        ]);

        expect(encoded, '0.123457,0.5,1.0');
      },
    );
  });
}
