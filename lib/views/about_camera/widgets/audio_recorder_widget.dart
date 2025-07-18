import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:provider/provider.dart';

import '../../../controllers/audio_controller.dart';
import '../../about_archiving/widgets/custom_waveform_widget.dart';

/// 오디오 녹음을 위한 위젯
///
/// 녹음 시작/중지 기능과 파형 표시 기능을 제공합니다.
/// AudioController을 사용하여 녹음 및 업로드 로직을 처리합니다.

// ✅ 녹음 상태 enum 추가
enum RecordingState {
  idle, // 녹음 대기
  recording, // 녹음 중
  recorded, // 녹음 완료 (재생 가능)
}

class AudioRecorderWidget extends StatefulWidget {
  // 콜백 함수 시그니처 변경: 파일 경로와 파형 데이터 함께 전달
  final Function(String?, List<double>?)? onRecordingCompleted;

  const AudioRecorderWidget({super.key, this.onRecordingCompleted});

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget> {
  // audio관련 기능을 가지고 있는 controller
  late AudioController _audioController;

  /// audio_waveforms 패키지의 녹음 컨트롤러를 설정
  late RecorderController recorderController;

  /// 재생 컨트롤러 (nullable로 변경)
  PlayerController? playerController;

  /// 현재 녹음 상태
  RecordingState _currentState = RecordingState.idle;

  /// 녹음된 파일 경로
  String? _recordedFilePath;

  /// 파형 데이터
  List<double>? _waveformData;

  @override
  void initState() {
    super.initState();
    // audio_waveforms 설정
    recorderController =
        RecorderController()
          ..androidEncoder = AndroidEncoder.aac
          ..androidOutputFormat = AndroidOutputFormat.mpeg4
          ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
          ..sampleRate = 44100;
    recorderController.checkPermission();

    // ✅ 재생 컨트롤러 초기화
    playerController = PlayerController();

    // Provider에서 필요한 Controller 가져오기
    _audioController = Provider.of<AudioController>(context, listen: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Provider에서 필요한 ViewModel 가져오기
    // This line might be redundant if _audioController is already initialized in initState
    // unless there's a specific reason to re-fetch it here (e.g., if the provider changes).
    _audioController = Provider.of<AudioController>(context, listen: false);
  }

  /// 녹음 시작 함수
  Future<void> _startRecording() async {
    // 파형 표시를 위한 녹음 컨트롤러 시작
    try {
      debugPrint('🎤 녹음 시작 준비...');

      // 파형을 그리는 패키지의 녹음 컨트롤러 시작
      debugPrint('📊 RecorderController 시작...');
      await recorderController.record();
      debugPrint('✅ RecorderController 시작 완료');

      // AudioController의 녹음 시작 함수 호출
      debugPrint('🔄 AudioController 녹음 시작...');
      await _audioController.startRecording();
      debugPrint('✅ AudioController 녹음 시작 완료');
      debugPrint('📁 현재 녹음 경로: ${_audioController.currentRecordingPath}');

      // ✅ 녹음 상태로 변경
      setState(() {
        _currentState = RecordingState.recording;
      });

      debugPrint('🎉 녹음 시작 완료 - 상태: ${_currentState}');
    } catch (e) {
      debugPrint('❌ 녹음 시작 오류: $e');
      setState(() {
        _currentState = RecordingState.idle;
      });
    }
  }

  /// 녹음 정지 후 즉시 재생 가능한 상태로 전환
  Future<void> _stopAndPreparePlayback() async {
    try {
      debugPrint('녹음 정지 및 재생 준비 시작...');

      // 파형 데이터 추출 (녹음 중지 전에 추출) - 원래 잘 작동하는 방식
      List<double> waveformData = List<double>.from(
        recorderController.waveData,
      );
      debugPrint('🌊 녹음 중 수집된 파형 데이터: ${waveformData.length} samples');

      // 파형 데이터 실제 레벨 유지 (정규화 없이) - 절댓값만 적용
      if (waveformData.isNotEmpty) {
        // 절댓값만 적용, 정규화는 하지 않음
        waveformData = waveformData.map((value) => value.abs()).toList();

        // 실제 최대값 확인용 로그
        double maxValue = waveformData.reduce((a, b) => a > b ? a : b);
        debugPrint('📊 파형 실제 최대값: $maxValue (정규화 없이)');
        debugPrint('📈 파형 샘플 (처음 5개): ${waveformData.take(5).toList()}');
      }

      // 녹음 중지
      final path = await recorderController.stop();
      await _audioController.stopRecordingSimple();

      // 재생 준비
      if (_audioController.currentRecordingPath != null &&
          _audioController.currentRecordingPath!.isNotEmpty &&
          playerController != null) {
        try {
          await playerController!.preparePlayer(
            path: _audioController.currentRecordingPath!,
            shouldExtractWaveform: true, // 파형 추출 활성화
          );

          // 파형 데이터가 비어있으면 PlayerController에서 추출
          if (waveformData.isEmpty) {
            debugPrint(
              '📊 RecorderController에서 파형이 비어있음, PlayerController에서 추출 시도',
            );
            final extractedWaveform = await playerController!
                .extractWaveformData(
                  path: _audioController.currentRecordingPath!,
                  noOfSamples: 100,
                );
            if (extractedWaveform.isNotEmpty) {
              waveformData = extractedWaveform;
              debugPrint(
                '✅ PlayerController에서 파형 추출 성공: ${waveformData.length} samples',
              );
            }
          }

          debugPrint('재생 준비 완료: ${_audioController.currentRecordingPath}');
        } catch (e) {
          debugPrint('재생 준비 오류: $e');
        }
      }

      setState(() {
        _currentState = RecordingState.recorded;
        _recordedFilePath = _audioController.currentRecordingPath;
        _waveformData = waveformData;
      });

      // ✅ 콜백 호출 추가 - 실제로 잘 작동하는 파형 데이터를 전달
      if (widget.onRecordingCompleted != null) {
        debugPrint('🎯 _stopAndPreparePlayback에서 콜백 함수 호출 중...');
        debugPrint('  - audioPath: ${_audioController.currentRecordingPath}');
        debugPrint('  - waveformData 길이: ${waveformData.length}');
        debugPrint('  - waveformData 샘플: ${waveformData.take(5).toList()}');

        widget.onRecordingCompleted!(
          _audioController.currentRecordingPath,
          waveformData,
        );

        debugPrint('✅ _stopAndPreparePlayback 콜백 함수 호출 완료');
      }

      debugPrint(
        '녹음 정지 및 재생 준비 완료, 최종 파형 데이터: ${_waveformData?.length ?? 0} samples',
      );
    } catch (e) {
      debugPrint('녹음 정지 오류: $e');
    }
  }

  /// 녹음 중지 함수
  Future<void> _stopRecording() async {
    try {
      debugPrint('녹음 중지 시작...');

      // 파형 데이터 추출 (원래 잘 작동하는 방식과 동일)
      List<double> waveformData = List<double>.from(
        recorderController.waveData,
      );
      debugPrint(
        '🌊 _stopRecording - 수집된 파형 데이터: ${waveformData.length} samples',
      );

      // 파형 데이터 처리 - 절댓값만 적용
      if (waveformData.isNotEmpty) {
        waveformData = waveformData.map((value) => value.abs()).toList();
        double maxValue = waveformData.reduce((a, b) => a > b ? a : b);
        debugPrint('📊 _stopRecording - 파형 최대값: $maxValue');
        debugPrint(
          '📈 _stopRecording - 파형 샘플 (처음 5개): ${waveformData.take(5).toList()}',
        );
      }

      // 녹음 중지
      final path = await recorderController.stop();
      debugPrint('📁 RecorderController 중지 완료, 경로: $path');

      // AudioController의 간단한 녹음 중지 함수 호출
      await _audioController.stopRecordingSimple();
      debugPrint('✅ AudioController 중지 완료');

      // 상태 업데이트
      setState(() {
        _currentState = RecordingState.recorded;
        _recordedFilePath = _audioController.currentRecordingPath;
        _waveformData = waveformData;
      });

      // 재생 컨트롤러 준비
      if (_recordedFilePath != null &&
          _recordedFilePath!.isNotEmpty &&
          playerController != null) {
        try {
          await playerController!.preparePlayer(
            path: _recordedFilePath!,
            shouldExtractWaveform: false, // 이미 파형 데이터가 있으므로
          );
          debugPrint('재생 컨트롤러 준비 완료: $_recordedFilePath');
        } catch (e) {
          debugPrint('재생 컨트롤러 준비 오류: $e');
        }
      }

      // 콜백이 있는 경우 녹음 파일 경로와 파형 데이터 함께 전달
      if (widget.onRecordingCompleted != null) {
        debugPrint('🎯 _stopRecording - 콜백 함수 호출 중...');
        debugPrint('  - audioPath: ${_audioController.currentRecordingPath}');
        debugPrint('  - waveformData 길이: ${waveformData.length}');
        debugPrint('  - waveformData 샘플: ${waveformData.take(5).toList()}');

        widget.onRecordingCompleted!(
          _audioController.currentRecordingPath,
          waveformData,
        );

        debugPrint('✅ _stopRecording - 콜백 함수 호출 완료');
      }

      debugPrint('🎉 _stopRecording - 녹음 중지 및 처리 완료');
    } catch (e) {
      debugPrint('❌ 녹음 중지 오류: $e');
      setState(() {
        _currentState = RecordingState.idle;
      });
    }
  }

  /// ✅ 재생/일시정지 토글 함수
  Future<void> _togglePlayback() async {
    if (playerController == null) return;

    try {
      if (playerController!.playerState.isPlaying) {
        await playerController!.pausePlayer();
        debugPrint('재생 일시정지');
      } else {
        // 재생이 끝났다면 처음부터 다시 시작
        if (playerController!.playerState.isStopped) {
          await playerController!.startPlayer();
          debugPrint('재생 시작 (처음부터)');
        } else {
          await playerController!.startPlayer();
          debugPrint('재생 시작');
        }
      }
      setState(() {}); // UI 갱신
    } catch (e) {
      debugPrint('재생/일시정지 오류: $e');
    }
  }

  /// ✅ 녹음 파일 삭제 함수
  void _deleteRecording() {
    try {
      // 재생 중이면 중지
      if (playerController?.playerState.isPlaying == true) {
        playerController?.stopPlayer();
      }

      // 상태 초기화
      setState(() {
        _currentState = RecordingState.idle;
        _recordedFilePath = null;
        _waveformData = null;
      });

      debugPrint('녹음 파일 삭제 완료');
    } catch (e) {
      debugPrint('녹음 파일 삭제 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 상태에 따라 다른 UI 표시
    switch (_currentState) {
      case RecordingState.idle:
        return GestureDetector(onTap: _startRecording, child: _buildIdleUI());

      case RecordingState.recording:
        return Selector<AudioController, String>(
          selector:
              (context, controller) => controller.formattedRecordingDuration,
          builder: (context, duration, child) {
            return _buildRecordingUI(duration);
          },
        );

      case RecordingState.recorded:
        return _buildPlaybackUI();
    }
  }

  Widget _buildRecordingUI(String duration) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: 376 / 393 * screenWidth,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xff1c1c1c),
        borderRadius: BorderRadius.circular(14.6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const SizedBox(width: 14),
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                shape: BoxShape.circle,
              ),
              child: Image.asset('assets/trash.png', width: 32, height: 32),
            ),
          ),
          const SizedBox(width: 19.5),
          Expanded(
            child: AudioWaveforms(
              size: const Size(
                1,
                52,
              ), // Adjust size as needed, 1 here is likely a placeholder
              recorderController: recorderController,
              waveStyle: const WaveStyle(
                waveColor: Colors.white,
                extendWaveform: true,
                showMiddleLine: false,
              ),
            ),
          ),
          Text(
            duration,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          IconButton(
            onPressed: () {
              _stopAndPreparePlayback();
            },
            icon: const Icon(Icons.stop, color: Colors.white),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  /// ✅ 재생 UI 빌드 (녹음 완료 후)
  Widget _buildPlaybackUI() {
    double screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: 376 / 393 * screenWidth,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xff1c1c1c), // 회색 배경
        borderRadius: BorderRadius.circular(14.6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const SizedBox(width: 14),

          // ✅ 쓰레기통 아이콘 (삭제)
          GestureDetector(
            onTap: _deleteRecording,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                shape: BoxShape.circle,
              ),
              child: Image.asset('assets/trash.png', width: 32, height: 32),
            ),
          ),

          const SizedBox(width: 19.5),

          // ✅ 재생 파형 (회색 배경에 흰색으로 채워짐)
          Expanded(
            child:
                _waveformData != null && _waveformData!.isNotEmpty
                    ? StreamBuilder<int>(
                      stream:
                          playerController?.onCurrentDurationChanged ??
                          const Stream.empty(),
                      builder: (context, positionSnapshot) {
                        final currentPosition = positionSnapshot.data ?? 0;
                        // maxDuration을 사용하여 총 길이 가져오기
                        final totalDuration =
                            playerController?.maxDuration ?? 1;
                        final progress =
                            totalDuration > 0
                                ? (currentPosition / totalDuration).clamp(
                                  0.0,
                                  1.0,
                                )
                                : 0.0;

                        return Container(
                          height: 20,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          child: CustomWaveformWidget(
                            waveformData: _waveformData!,
                            color: Colors.grey, // 재생 안 된 부분
                            activeColor: Colors.white, // 재생된 부분
                            progress: progress,
                          ),
                        );
                      },
                    )
                    : Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          '파형 없음',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                    ),
          ),

          // ✅ 재생 시간 표시
          StreamBuilder<int>(
            stream:
                playerController?.onCurrentDurationChanged ??
                const Stream.empty(),
            builder: (context, snapshot) {
              final currentDurationMs = snapshot.data ?? 0;
              final currentDuration = Duration(milliseconds: currentDurationMs);
              final minutes = currentDuration.inMinutes;
              final seconds = currentDuration.inSeconds % 60;
              return Text(
                '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              );
            },
          ),

          // ✅ 재생/일시정지 버튼
          IconButton(
            onPressed: _togglePlayback,
            icon: StreamBuilder<PlayerState>(
              stream:
                  playerController?.onPlayerStateChanged ??
                  const Stream.empty(),
              builder: (context, snapshot) {
                final isPlaying = snapshot.data?.isPlaying ?? false;
                return Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                );
              },
            ),
          ),

          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildIdleUI() {
    return Image.asset('assets/record_icon.png', width: 64, height: 64);
  }

  @override
  void dispose() {
    recorderController.dispose();
    playerController?.dispose(); // ✅ 재생 컨트롤러도 dispose (null 체크)
    super.dispose();
  }
}
