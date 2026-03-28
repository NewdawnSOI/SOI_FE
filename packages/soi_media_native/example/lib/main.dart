import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:soi_media_native/soi_media_native.dart' as soi_media_native;

const int _probeIterations = 400;
const int _waveformIterations = 250;
const int _waveformSourceLength = 60000;
const int _waveformTargetLength = 180;

/// 예제 앱을 실행해 현재 FFI로 구현된 경로의 마이크로 벤치마크를 확인합니다.
void main() {
  runApp(const SoiMediaNativeBenchmarkApp());
}

/// 패키지 단독 벤치마크 화면을 감싸는 최상위 앱 위젯입니다.
class SoiMediaNativeBenchmarkApp extends StatelessWidget {
  const SoiMediaNativeBenchmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1C6E5D)),
        scaffoldBackgroundColor: const Color(0xFFF4F1EA),
        useMaterial3: true,
      ),
      home: const _BenchmarkHomePage(),
    );
  }
}

/// 현재 패키지의 실제 native 경로와 pure Dart 기준선을 비교해 수치를 보여줍니다.
class _BenchmarkHomePage extends StatefulWidget {
  const _BenchmarkHomePage();

  @override
  State<_BenchmarkHomePage> createState() => _BenchmarkHomePageState();
}

/// 벤치마크 실행 상태와 결과를 관리하고, 필요할 때 다시 측정합니다.
class _BenchmarkHomePageState extends State<_BenchmarkHomePage> {
  bool _isRunning = false;
  String? _errorMessage;
  List<_BenchmarkScenarioResult> _results = const <_BenchmarkScenarioResult>[];

  @override
  void initState() {
    super.initState();
    unawaited(_runBenchmarks());
  }

  /// 두 시나리오를 순차 실행해 화면에 최신 벤치마크 결과를 반영합니다.
  Future<void> _runBenchmarks() async {
    if (_isRunning) {
      return;
    }

    setState(() {
      _isRunning = true;
      _errorMessage = null;
    });

    try {
      final probeImageFile = await _createProbeBenchmarkImage();
      final probeScenario = await _benchmarkImageProbe(probeImageFile);
      final waveformScenario = _benchmarkWaveformSampling();

      if (!mounted) {
        return;
      }

      setState(() {
        _results = <_BenchmarkScenarioResult>[probeScenario, waveformScenario];
        _isRunning = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRunning = false;
        _errorMessage = error.toString();
      });
    }
  }

  /// 이미지 probe 비교용 PNG를 시스템 임시 폴더에 준비합니다.
  Future<File> _createProbeBenchmarkImage() async {
    final file = File(
      '${Directory.systemTemp.path}/soi_media_native_probe_benchmark.png',
    );
    await file.writeAsBytes(_tinyPng, flush: true);
    return file;
  }

  /// `probeImage`와 `ui.instantiateImageCodec` 기반 기준선을 반복 측정합니다.
  Future<_BenchmarkScenarioResult> _benchmarkImageProbe(File file) async {
    final ffiDuration = await _measureAsync(() async {
      for (var index = 0; index < _probeIterations; index++) {
        await soi_media_native.probeImage(file.path);
      }
    });

    final dartDuration = await _measureAsync(() async {
      for (var index = 0; index < _probeIterations; index++) {
        await _probeImageWithCodec(file);
      }
    });

    final ffiResult = await soi_media_native.probeImage(file.path);
    final dartResult = await _probeImageWithCodec(file);

    return _BenchmarkScenarioResult(
      title: 'Image Probe',
      nativeLabel: 'FFI probeImage',
      baselineLabel: 'ui.instantiateImageCodec',
      nativeDuration: ffiDuration,
      baselineDuration: dartDuration,
      summary:
          'native=${ffiResult?.width}x${ffiResult?.height} / '
          'dart=${dartResult?.width}x${dartResult?.height}',
      note:
          '현재 패키지에서 실제 C 코드가 수행되는 경로입니다. '
          'tiny PNG 기준의 마이크로 벤치마크라 절대값보다 상대 비교를 보는 용도입니다.',
    );
  }

  /// `sampleWaveform`와 기존 Dart 샘플링 루프를 같은 입력으로 비교합니다.
  _BenchmarkScenarioResult _benchmarkWaveformSampling() {
    final source = List<double>.generate(
      _waveformSourceLength,
      (index) => (math.sin(index / 14) * 0.6 + math.cos(index / 9) * 0.4).abs(),
      growable: false,
    );

    final ffiDuration = _measureSync(() {
      for (var index = 0; index < _waveformIterations; index++) {
        soi_media_native.sampleWaveform(source, _waveformTargetLength);
      }
    });

    final dartDuration = _measureSync(() {
      for (var index = 0; index < _waveformIterations; index++) {
        _sampleWaveformInDart(source, _waveformTargetLength);
      }
    });

    final ffiSample = soi_media_native.sampleWaveform(
      source,
      _waveformTargetLength,
    );
    final dartSample = _sampleWaveformInDart(source, _waveformTargetLength);

    return _BenchmarkScenarioResult(
      title: 'Waveform Sampling',
      nativeLabel: 'FFI sampleWaveform',
      baselineLabel: 'pure Dart loop',
      nativeDuration: ffiDuration,
      baselineDuration: dartDuration,
      summary:
          'source=${source.length} -> target=${ffiSample.length}, '
          'head(native)=${ffiSample.take(4).map((value) => value.toStringAsFixed(3)).join(', ')} / '
          'head(dart)=${dartSample.take(4).map((value) => value.toStringAsFixed(3)).join(', ')}',
      note: '댓글/웨이브폼 축약처럼 큰 리스트를 자주 다루는 경로를 가정한 반복 측정입니다.',
    );
  }

  /// 기존 앱 로직과 유사한 codec 기반 이미지 probe 경로를 기준선으로 사용합니다.
  Future<_ImageSize?> _probeImageWithCodec(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final result = _ImageSize(width: image.width, height: image.height);
    image.dispose();
    codec.dispose();
    return result;
  }

  /// legacy backend와 같은 균일 샘플링 규칙을 Dart만으로 다시 계산합니다.
  List<double> _sampleWaveformInDart(List<double> source, int maxLength) {
    if (source.isEmpty || maxLength <= 0 || source.length <= maxLength) {
      return List<double>.from(source);
    }

    final step = source.length / maxLength;
    return List<double>.generate(
      maxLength,
      (index) => source[(index * step).floor()],
      growable: false,
    );
  }

  /// 비동기 작업의 총 소요 시간을 재사용 가능한 형태로 측정합니다.
  Future<Duration> _measureAsync(Future<void> Function() action) async {
    final stopwatch = Stopwatch()..start();
    await action();
    stopwatch.stop();
    return stopwatch.elapsed;
  }

  /// 동기 작업의 총 소요 시간을 재사용 가능한 형태로 측정합니다.
  Duration _measureSync(void Function() action) {
    final stopwatch = Stopwatch()..start();
    action();
    stopwatch.stop();
    return stopwatch.elapsed;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOI Media Native Benchmark'),
        actions: [
          TextButton.icon(
            onPressed: _isRunning ? null : _runBenchmarks,
            icon: const Icon(Icons.refresh),
            label: const Text('Run Again'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 24,
                  color: Color(0x14000000),
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This example benchmarks only the APIs that are actually backed by native C today.',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF17322C),
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'This package only owns image probing, image compression, and waveform sampling. '
                  'The example stays focused on those native paths so the benchmark result is easy to read.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Color(0xFF4D5E59),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_isRunning)
            LinearProgressIndicator(
              minHeight: 6,
              borderRadius: BorderRadius.circular(999),
            ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F0),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFFC7C2)),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Color(0xFF7A261A)),
              ),
            ),
          ],
          const SizedBox(height: 18),
          for (final result in _results) ...[
            _BenchmarkResultCard(
              result: result,
              accentColor: colorScheme.primary,
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

/// 한 벤치마크 시나리오의 측정값과 화면 표시용 설명을 함께 보관합니다.
class _BenchmarkScenarioResult {
  const _BenchmarkScenarioResult({
    required this.title,
    required this.nativeLabel,
    required this.baselineLabel,
    required this.nativeDuration,
    required this.baselineDuration,
    required this.summary,
    required this.note,
  });

  final String title;
  final String nativeLabel;
  final String baselineLabel;
  final Duration nativeDuration;
  final Duration baselineDuration;
  final String summary;
  final String note;

  double get nativeMs => nativeDuration.inMicroseconds / 1000;
  double get baselineMs => baselineDuration.inMicroseconds / 1000;

  String get deltaLabel {
    if (nativeDuration.inMicroseconds == baselineDuration.inMicroseconds) {
      return 'same timing';
    }

    if (nativeDuration.inMicroseconds < baselineDuration.inMicroseconds) {
      final ratio =
          baselineDuration.inMicroseconds / nativeDuration.inMicroseconds;
      return '${ratio.toStringAsFixed(2)}x faster';
    }

    final ratio =
        nativeDuration.inMicroseconds / baselineDuration.inMicroseconds;
    return '${ratio.toStringAsFixed(2)}x slower';
  }
}

/// 결과 카드 하나를 그려 시나리오별 native/baseline 비교를 읽기 쉽게 보여줍니다.
class _BenchmarkResultCard extends StatelessWidget {
  const _BenchmarkResultCard({required this.result, required this.accentColor});

  final _BenchmarkScenarioResult result;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3DED4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF17322C),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  result.deltaLabel,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TimingRow(label: result.nativeLabel, valueMs: result.nativeMs),
          const SizedBox(height: 8),
          _TimingRow(label: result.baselineLabel, valueMs: result.baselineMs),
          const SizedBox(height: 14),
          Text(
            result.summary,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFF465550),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            result.note,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Color(0xFF6A7773),
            ),
          ),
        ],
      ),
    );
  }
}

/// 한 줄 timing 표기를 재사용해 native/baseline 값을 같은 형식으로 맞춥니다.
class _TimingRow extends StatelessWidget {
  const _TimingRow({required this.label, required this.valueMs});

  final String label;
  final double valueMs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF17322C),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          '${valueMs.toStringAsFixed(3)} ms',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF17322C),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// codec 기준선이 읽은 이미지 크기를 가볍게 전달하는 값 객체입니다.
class _ImageSize {
  const _ImageSize({required this.width, required this.height});

  final int width;
  final int height;
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
  0x18,
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
