import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:soi/api/media_processing/media_processing_backend.dart';
import 'package:soi/views/about_profile/services/profile_data_service.dart';

import '../../../support/fake_media_processing_backend.dart';

/// EXIF 정규화 테스트가 실제 표시 결과를 비교할 수 있도록 픽셀 배치를 검증합니다.
void expectImagesMatch(
  img.Image actual,
  img.Image expected, {
  int tolerance = 2,
}) {
  expect(actual.width, expected.width);
  expect(actual.height, expected.height);

  for (var y = 0; y < expected.height; y++) {
    for (var x = 0; x < expected.width; x++) {
      final actualPixel = actual.getPixel(x, y);
      final expectedPixel = expected.getPixel(x, y);

      expect(
        (actualPixel.r - expectedPixel.r).abs(),
        lessThanOrEqualTo(tolerance),
      );
      expect(
        (actualPixel.g - expectedPixel.g).abs(),
        lessThanOrEqualTo(tolerance),
      );
      expect(
        (actualPixel.b - expectedPixel.b).abs(),
        lessThanOrEqualTo(tolerance),
      );
      expect(
        (actualPixel.a - expectedPixel.a).abs(),
        lessThanOrEqualTo(tolerance),
      );
    }
  }
}

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
      'compressProfileImage normalizes rotational EXIF data before delegating to the backend',
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
        final expectedImage = img.decodeImage(await originalFile.readAsBytes());

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
                  expectImagesMatch(preparedImage, expectedImage!);

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
      'compressProfileImage keeps mirrored EXIF data from flipping pixels again',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'profile_data_service_mirror_orientation_test',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final sourceImage = img.Image(width: 2, height: 1)
          ..setPixelRgba(0, 0, 255, 0, 0, 255)
          ..setPixelRgba(1, 0, 0, 255, 0, 255);
        final exif = img.ExifData()..imageIfd.orientation = 2;

        final originalFile = File('${tempDir.path}/profile.jpg');
        await originalFile.writeAsBytes(
          img.injectJpgExif(img.encodeJpg(sourceImage, quality: 100), exif) ??
              img.encodeJpg(sourceImage, quality: 100),
          flush: true,
        );
        final expectedImage = img.decodeImage(await originalFile.readAsBytes());

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
                  expectImagesMatch(preparedImage, expectedImage!);

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
