import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../api/controller/audio_controller.dart';
import 'audio_recorder_widget.dart';
import 'caption_input_widget.dart';

class PhotoEditorInputBar extends StatelessWidget {
  const PhotoEditorInputBar({
    super.key,
    required this.showAudioRecorder,
    required this.audioController,
    required this.captionController,
    required this.captionFocusNode,
    required this.isCaptionEmpty,
    required this.onMicTap,
    required this.onRecordingFinished,
    required this.onRecordingCleared,
    this.recordedAudioPath,
    this.recordedWaveformData,
  });

  final bool showAudioRecorder;
  final AudioController audioController;
  final TextEditingController captionController;
  final FocusNode captionFocusNode;
  final bool isCaptionEmpty;
  final VoidCallback onMicTap;
  final void Function(
    String audioFilePath,
    List<double> waveformData,
    Duration duration,
  )
  onRecordingFinished;
  final VoidCallback onRecordingCleared;
  final String? recordedAudioPath;
  final List<double>? recordedWaveformData;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: showAudioRecorder
          ? Padding(
              key: const ValueKey('audio_recorder'),
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: AudioRecorderWidget(
                audioController: audioController,
                autoStart: true,
                onRecordingFinished: onRecordingFinished,
                onRecordingCleared: onRecordingCleared,
                initialRecordingPath: recordedAudioPath,
                initialWaveformData: recordedWaveformData,
              ),
            )
          : FocusScope(
              key: const ValueKey('caption_input'),
              child: CaptionInputWidget(
                controller: captionController,
                isCaptionEmpty: isCaptionEmpty,
                onMicTap: onMicTap,
                focusNode: captionFocusNode,
              ),
            ),
    );
  }
}
