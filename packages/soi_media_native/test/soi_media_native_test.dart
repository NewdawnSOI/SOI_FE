import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:soi_media_native/soi_media_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SoiMediaNative', () {
    test('probeImage reads png dimensions through native code', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'soi_media_native_test',
      );
      final pngFile = File('${tempDir.path}/tiny.png');
      await pngFile.writeAsBytes(_tinyPng);

      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final result = await probeImage(pngFile.path);
      expect(result, isNotNull);
      expect(result?.width, 1);
      expect(result?.height, 1);
    });

    test('sampleWaveform keeps evenly spaced values', () {
      final sampled = sampleWaveform(<double>[0, 1, 2, 3, 4, 5], 3);
      expect(sampled, <double>[0, 2, 4]);
    });

    test('encodeWaveform and decodeWaveform keep request compatibility', () {
      final encoded = encodeWaveform(<double>[
        0.123456,
        0.987654,
        0.5,
      ], maxSamples: 2);
      expect(encoded, '[0.1235,0.9877]');
      expect(decodeWaveform(encoded), <double>[0.1235, 0.9877]);
      expect(decodeWaveform('0.1, 0.2, 0.3'), <double>[0.1, 0.2, 0.3]);
    });

    test('compressImage writes a native webp file', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'soi_media_native_compress_test',
      );
      final input = File('${tempDir.path}/in.png');
      final output = '${tempDir.path}/out.webp';
      await input.writeAsBytes(await _createTestPngBytes());

      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      const client = SoiMediaNativeClient();
      final compressed = await client.compressImage(
        inputPath: input.path,
        outputPath: output,
        quality: 80,
        minWidth: 100,
        minHeight: 100,
      );

      expect(compressed, isNotNull);
      expect(await compressed!.exists(), isTrue);
      final bytes = await compressed.readAsBytes();
      expect(bytes.take(4).toList(), <int>[0x52, 0x49, 0x46, 0x46]);
      final outputProbe = await probeImage(compressed.path);
      expect(outputProbe?.width, 8);
      expect(outputProbe?.height, 6);
    });
  });
}

const List<int> _tinyPng = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0x00,
  0x00,
  0x03,
  0x01,
  0x01,
  0x00,
  0x18,
  0xDD,
  0x8D,
  0xB1,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

Future<Uint8List> _createTestPngBytes() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()..color = const ui.Color(0xFF2E9D74);
  canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 8, 6), paint);

  final picture = recorder.endRecording();
  final image = await picture.toImage(8, 6);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw StateError('failed to create png bytes for test');
    }
    return bytes.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
