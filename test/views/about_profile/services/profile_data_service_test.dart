import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:soi/api/media_processing/media_processing_backend.dart';
import 'package:soi/views/about_profile/services/profile_data_service.dart';

import '../../../support/fake_media_processing_backend.dart';

void main() {
  group('ProfileDataService', () {
    test('compressProfileImage reuses the shared media backend', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'profile_data_service_test',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final originalFile = File('${tempDir.path}/profile.jpg');
      await originalFile.writeAsBytes(Uint8List(4096), flush: true);

      final service = ProfileDataService(
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
                expect(inputFile.path, originalFile.path);
                expect(format, MediaImageOutputFormat.webp);
                final compressedFile = File(outputPath);
                await compressedFile.writeAsBytes(Uint8List(1024), flush: true);
                return compressedFile;
              },
        ),
      );

      final result = await service.compressProfileImage(originalFile);

      expect(result.path, isNot(originalFile.path));
      expect(await result.length(), 1024);
    });

    test(
      'compressProfileImage bakes EXIF orientation before delegating to the backend',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'profile_data_service_orientation_test',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final sourceImage = img.Image(width: 1, height: 2)
          ..setPixelRgba(0, 0, 255, 0, 0, 255)
          ..setPixelRgba(0, 1, 0, 0, 255, 255);
        final exif = img.ExifData()..imageIfd.orientation = 3;

        final originalFile = File('${tempDir.path}/profile.jpg');
        await originalFile.writeAsBytes(
          img.injectJpgExif(img.encodeJpg(sourceImage, quality: 100), exif) ??
              img.encodeJpg(sourceImage, quality: 100),
          flush: true,
        );

        late String preparedInputPath;
        final service = ProfileDataService(
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
                  preparedInputPath = inputFile.path;
                  final preparedImage = img.decodeImage(
                    await inputFile.readAsBytes(),
                  );

                  expect(preparedImage, isNotNull);
                  expect(preparedImage!.exif.imageIfd.orientation, isNull);
                  expect(
                    preparedImage.getPixel(0, 0).b >
                        preparedImage.getPixel(0, 0).r,
                    isTrue,
                  );
                  expect(
                    preparedImage.getPixel(0, 1).r >
                        preparedImage.getPixel(0, 1).b,
                    isTrue,
                  );

                  final compressedFile = File(outputPath);
                  await compressedFile.writeAsBytes(
                    Uint8List(1024),
                    flush: true,
                  );
                  return compressedFile;
                },
          ),
        );

        final result = await service.compressProfileImage(originalFile);

        expect(preparedInputPath, isNotEmpty);
        expect(result.path, isNot(preparedInputPath));
        expect(await result.length(), 1024);
      },
    );

    test(
      'compressProfileImage falls back to the original file on backend failure',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'profile_data_service_fallback_test',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final originalFile = File('${tempDir.path}/profile.jpg');
        await originalFile.writeAsBytes(Uint8List(4096), flush: true);

        final service = ProfileDataService(
          mediaProcessingBackend: FakeMediaProcessingBackend(
            onCompressImage:
                ({
                  required inputFile,
                  required outputPath,
                  required quality,
                  required minWidth,
                  required minHeight,
                  required format,
                }) async => null,
          ),
        );

        final result = await service.compressProfileImage(originalFile);

        expect(result.path, originalFile.path);
      },
    );
  });
}
