import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soi/views/about_camera/services/photo_editor_media_processing_service.dart';
import 'package:soi/views/about_camera/services/photo_editor_screen_init_service.dart';

void main() {
  late PhotoEditorScreenInitService service;

  setUp(() {
    service = PhotoEditorScreenInitService(
      mediaProcessingService: PhotoEditorMediaProcessingService(),
    );
  });

  group('PhotoEditorScreenInitService', () {
    test('isTextOnlyMode matches text-only payload rules', () {
      expect(
        PhotoEditorScreenInitService.isTextOnlyMode(
          inputText: ' hello ',
          filePath: null,
          asset: null,
          downloadUrl: null,
        ),
        isTrue,
      );

      expect(
        PhotoEditorScreenInitService.isTextOnlyMode(
          inputText: ' hello ',
          filePath: '/tmp/photo.jpg',
          asset: null,
          downloadUrl: null,
        ),
        isFalse,
      );

      expect(PhotoEditorScreenInitService.textOnlyContent(' hello '), 'hello');
    });

    test(
      'primeImmediatePreview keeps initial image preview without file IO',
      () {
        final previewState = service.primeImmediatePreview(
          initialImage: MemoryImage(Uint8List.fromList([0, 1, 2])),
          filePath: null,
        );

        expect(previewState.isLoading, isFalse);
        expect(previewState.showImmediatePreview, isTrue);
        expect(previewState.useLocalImage, isTrue);
        expect(previewState.initialImageProvider, isA<ImageProvider>());
      },
    );

    test(
      'loadImage resolves an existing file into local preview state',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'photo_editor_screen_init_service_test',
        );
        final imageFile = File('${tempDir.path}/preview.jpg');
        await imageFile.writeAsBytes(<int>[1, 2, 3]);

        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final previewState = await service.loadImage(
          filePath: imageFile.path,
          showImmediatePreview: false,
          initialImageProvider: null,
          useLocalImage: false,
        );

        expect(previewState.isLoading, isFalse);
        expect(previewState.showImmediatePreview, isTrue);
        expect(previewState.useLocalImage, isTrue);
        expect(previewState.resolvedFilePath, imageFile.path);
        expect(previewState.errorMessageKey, isNull);
      },
    );
  });
}
