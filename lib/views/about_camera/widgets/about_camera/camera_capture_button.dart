import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'circular_video_progress_indicator.dart';
import 'pressable_container.dart';

/// 카메라 촬영 버튼 위젯
///
/// 사진 촬영 및 비디오 녹화 기능을 제공하는 버튼입니다.
///
/// Parameters:
/// - [isVideoRecording]: 현재 비디오 녹화 상태를 나타내는 불리언 값입니다.
/// - [videoProgress]: 비디오 녹화 진행 상황을 나타내는 ValueListenable 객체입니다.
/// - [onTakePicture]: 사진 촬영 시 호출되는 콜백 함수입니다.
/// - [onStartVideoRecording]: 비디오 녹화 시작 시 호출되는 콜백 함수입니다.
/// - [onStopVideoRecording]: 비디오 녹화 중지 시 호출되는 콜백 함수입니다.
class CameraCaptureButton extends StatefulWidget {
  const CameraCaptureButton({
    required this.isVideoRecording,
    required this.videoProgress,
    required this.onTakePicture,
    required this.onStartVideoRecording,
    required this.onStopVideoRecording,
    super.key,
  });

  final bool isVideoRecording;
  final ValueListenable<double> videoProgress;
  final VoidCallback onTakePicture;
  final Future<void> Function() onStartVideoRecording;
  final VoidCallback onStopVideoRecording;

  @override
  State<CameraCaptureButton> createState() => _CameraCaptureButtonState();
}

class _CameraCaptureButtonState extends State<CameraCaptureButton> {
  bool _isPreparingVideo = false;

  bool get _showVideoCaptureState =>
      widget.isVideoRecording || _isPreparingVideo;

  @override
  void didUpdateWidget(covariant CameraCaptureButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.isVideoRecording && widget.isVideoRecording) {
      _isPreparingVideo = false;
      return;
    }

    if (oldWidget.isVideoRecording && !widget.isVideoRecording) {
      _isPreparingVideo = false;
    }
  }

  void _handleVideoLongPressStart(LongPressStartDetails details) {
    if (widget.isVideoRecording || _isPreparingVideo) {
      return;
    }

    setState(() {
      _isPreparingVideo = true;
    });
  }

  Future<void> _handleStartVideoRecording() async {
    if (widget.isVideoRecording) {
      return;
    }

    if (!_isPreparingVideo) {
      setState(() {
        _isPreparingVideo = true;
      });
    }

    await widget.onStartVideoRecording();
    if (!mounted || widget.isVideoRecording) {
      return;
    }

    setState(() {
      _isPreparingVideo = false;
    });
  }

  Widget _buildVideoButton() {
    return AnimatedScale(
      key: const ValueKey<String>('video_recording_button'),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      scale: widget.isVideoRecording ? 1.0 : 0.94,
      child: SizedBox(
        height: 90.h,
        child: ValueListenableBuilder<double>(
          valueListenable: widget.videoProgress,
          builder: (context, progress, child) {
            return GestureDetector(
              onTap: widget.isVideoRecording
                  ? widget.onStopVideoRecording
                  : null,
              child: CircularVideoProgressIndicator(
                progress: progress,
                innerSize: 40.42,
                gap: 15.29,
                strokeWidth: 3.0,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPhotoButton() {
    return PressableContainer(
      key: const ValueKey<String>('photo_capture_button'),
      onTap: widget.onTakePicture,
      onLongPressStart: _handleVideoLongPressStart,
      onLongPress: () => unawaited(_handleStartVideoRecording()),
      padding: EdgeInsets.zero,
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: Image.asset("assets/take_picture.png", width: 65, height: 65),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90.w,
      height: 90.h,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          reverseDuration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.center,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          transitionBuilder: (child, animation) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
                child: child,
              ),
            );
          },
          child: _showVideoCaptureState
              ? _buildVideoButton()
              : _buildPhotoButton(),
        ),
      ),
    );
  }
}
