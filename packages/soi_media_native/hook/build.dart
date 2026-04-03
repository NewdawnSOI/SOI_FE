import 'dart:io';

import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:hooks/hooks.dart';

const List<String> _libwebpSourceDirectories = <String>[
  'third_party/libwebp/src/dec',
  'third_party/libwebp/src/dsp',
  'third_party/libwebp/src/enc',
  'third_party/libwebp/src/utils',
  'third_party/libwebp/sharpyuv',
];

/// libwebp와 패키지 C 코어를 함께 컴파일해 이미지 FFI 기능을 한 라이브러리에 묶습니다.
void main(List<String> args) async {
  await build(args, (input, output) async {
    final packageName = input.packageName;
    final cbuilder = CBuilder.library(
      name: packageName,
      assetName: '${packageName}_bindings_generated.dart',
      sources: <String>['src/$packageName.c', ..._collectThirdPartySources()],
      includes: const <String>['third_party/libwebp', 'third_party/stb'],
    );
    await cbuilder.run(input: input, output: output);
  });
}

/// libwebp에서 현재 encode/decode 경로에 필요한 C 소스만 모아 빌드 시간을 줄입니다.
List<String> _collectThirdPartySources() {
  final sources = <String>[];
  for (final directoryPath in _libwebpSourceDirectories) {
    sources.addAll(_collectCSources(directoryPath));
  }
  return sources;
}

/// 지정된 디렉터리 아래의 C 소스를 정렬해 재현 가능한 빌드 입력 목록을 만듭니다.
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
