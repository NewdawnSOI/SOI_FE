import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:soi/utils/media_processing/media_processing_backend.dart';
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
