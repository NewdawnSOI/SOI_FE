import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

/// 앱 최초 실행 시 한 번만 재생되는 인트로 비디오 화면
class LaunchVideoScreen extends StatefulWidget {
  const LaunchVideoScreen({super.key});

  @override
  State<LaunchVideoScreen> createState() => _LaunchVideoScreenState();
}

class _LaunchVideoScreenState extends State<LaunchVideoScreen> {
  late final VideoPlayerController _controller;
  bool _initialized = false;
  bool _completed = false;
  double _opacity = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/app_launch_video/SOI.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
        _controller
          ..setLooping(false)
          ..play();
      });

    _controller.addListener(_handleProgress);
  }

  void _handleProgress() {
    final value = _controller.value;
    if (!value.isInitialized || _completed) return;

    if (value.position >= value.duration) {
      _completeAndNavigate();
    }
  }

  Future<void> _completeAndNavigate() async {
    if (_completed) return;
    _completed = true;
    setState(() => _opacity = 0);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenLaunchVideo', true);

    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  void dispose() {
    _controller.removeListener(_handleProgress);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        opacity: _opacity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: _initialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : const CircularProgressIndicator(color: Colors.white),
            ),
            Positioned(
              top: 50,
              right: 20,
              child: TextButton(
                onPressed: _completeAndNavigate,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.black54,
                ),
                child: const Text('건너뛰기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
