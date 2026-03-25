import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:soi/api/controller/audio_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioController', () {
    test(
      'primeRecorderIfPermitted warms recorder once after microphone permission is granted',
      () async {
        var microphoneGranted = false;
        var warmupCallCount = 0;

        final controller = AudioController(
          loadMicrophonePermissionStatus: () async {
            return microphoneGranted
                ? PermissionStatus.granted
                : PermissionStatus.denied;
          },
          primeRecorderResources: () async {
            warmupCallCount++;
          },
        );

        await controller.primeRecorderIfPermitted();
        await controller.primeRecorderIfPermitted();
        expect(warmupCallCount, 0);

        microphoneGranted = true;

        await controller.primeRecorderIfPermitted();
        await controller.primeRecorderIfPermitted();
        expect(warmupCallCount, 1);
      },
    );

    test('primeRecorderIfPermitted dedupes in-flight warmup calls', () async {
      final warmupCompleter = Completer<void>();
      var warmupCallCount = 0;

      final controller = AudioController(
        loadMicrophonePermissionStatus: () async => PermissionStatus.granted,
        primeRecorderResources: () {
          warmupCallCount++;
          return warmupCompleter.future;
        },
      );

      final first = controller.primeRecorderIfPermitted();
      final second = controller.primeRecorderIfPermitted();

      await Future<void>.delayed(Duration.zero);

      expect(warmupCallCount, 1);

      warmupCompleter.complete();
      await Future.wait([first, second]);
    });
  });
}
