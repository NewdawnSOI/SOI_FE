import 'dart:io';

import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:logging/logging.dart';
import 'package:hooks/hooks.dart';

/// libwebp와 패키지 C 코어를 함께 컴파일해 이미지 FFI 기능을 한 라이브러리에 묶습니다.
void main(List<String> args) async {
  await build(args, (input, output) async {
    final packageName = input.packageName;
    final cbuilder = CBuilder.library(
      name: packageName,
      assetName: '${packageName}_bindings_generated.dart',
      sources: <String>[
        'src/$packageName.c',
        ..._collectCSources('third_party/libwebp/src'),
        ..._collectCSources('third_party/libwebp/sharpyuv'),
      ],
      includes: const <String>['third_party/libwebp', 'third_party/stb'],
    );
    await cbuilder.run(
      input: input,
      output: output,
      logger: Logger('')
        ..level = Level.ALL
        ..onRecord.listen((record) => print(record.message)),
    );
  });
}

List<String> _collectCSources(String directoryPath) {
  final directory = Directory(directoryPath);
  final sources =
      directory
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.path.replaceAll('\\', '/'))
          .where((path) => path.endsWith('.c'))
          .toList()
        ..sort();
  return sources;
}
