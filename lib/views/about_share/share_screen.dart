import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:another_flushbar/flushbar.dart';
import '../about_archiving/widgets/wave_form_widget/custom_waveform_widget.dart';

class ShareScreen extends StatefulWidget {
  final String imageUrl;
  final List<double>? waveformData;
  final Duration audioDuration;
  final String categoryName;

  const ShareScreen({
    super.key,
    required this.imageUrl,
    this.waveformData,
    required this.audioDuration,
    required this.categoryName,
  });

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final GlobalKey _containerKey = GlobalKey();

  /// 권한 요청 메소드
  Future<bool> _requestStoragePermission() async {
    // photo_manager의 권한 요청 사용
    final PermissionState ps = await PhotoManager.requestPermissionExtend();

    if (ps.isAuth) {
      return true;
    } else if (ps.hasAccess) {
      return true;
    } else {
      // 권한이 거부된 경우
      return false;
    }
  }

  /// 이미지 다운로드 메소드
  Future<void> _downloadImage() async {
    try {
      // 권한 확인
      bool hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        _showErrorMessage('저장소 접근 권한이 필요합니다.');
        return;
      }

      // RepaintBoundary를 통해 위젯을 이미지로 캡처
      RenderRepaintBoundary boundary =
          _containerKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;

      // 최고 화질로 캡처 (pixelRatio 3.0)
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // 갤러리에 저장
      final result = await ImageGallerySaver.saveImage(
        pngBytes,
        quality: 100, // 최고 화질
        name: "SOI_${DateTime.now().millisecondsSinceEpoch}",
      );

      if (result['isSuccess'] == true) {
        _showSuccessMessage('이미지가 갤러리에 저장되었습니다!');
      } else {
        _showErrorMessage('이미지 저장에 실패했습니다.');
      }
    } catch (e) {
      _showErrorMessage('이미지 저장에 실패했습니다: $e');
    }
  }

  /// 성공 메시지 표시
  void _showSuccessMessage(String message) {
    Flushbar(
      message: message,
      backgroundColor: const Color(0xFF323232),
      duration: const Duration(seconds: 3),
      borderRadius: BorderRadius.circular(16.5),
      margin: EdgeInsets.all(16.w),
      icon: Icon(Icons.check_circle, color: Colors.green, size: 24.sp),
    ).show(context);
  }

  /// 에러 메시지 표시
  void _showErrorMessage(String message) {
    Flushbar(
      message: message,
      backgroundColor: const Color(0xFF5A5A5A),
      duration: const Duration(seconds: 3),
      borderRadius: BorderRadius.circular(16.5),
      margin: EdgeInsets.all(16.w),
      icon: Icon(Icons.error, color: Colors.red, size: 24.sp),
    ).show(context);
  }

  @override
  void initState() {
    super.initState();
    _requestStoragePermission();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xff000000),
      body: Column(
        children: [
          SizedBox(height: 85.h),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Color(0xff1c1c1c),
                borderRadius: BorderRadius.circular(18.6),
              ),
              child: Column(
                children: [
                  SizedBox(height: 17.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 17.w),
                        child: IconButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          icon: Image.asset(
                            "assets/cancel_icon.png",
                            width: 30.2.w,
                            height: 30.2.h,
                          ),
                        ),
                      ),
                      Text(
                        "공유하기",
                        style: TextStyle(
                          color: Color(0xfff8f8f8),
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                          fontFamily: "Pretendard",
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(right: 17.w),
                        child: IconButton(
                          onPressed: _downloadImage,
                          icon: Image.asset(
                            "assets/download_icon.png",
                            width: 25.w,
                            height: 25.h,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Divider(color: Color(0xff595959), thickness: 1, height: 1),
                  SizedBox(height: 22.5.h),
                  RepaintBoundary(
                    key: _containerKey,
                    child: Container(
                      width: 295.w,
                      height: 504.h,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          SizedBox(height: 16.h),
                          Text(
                            "SOI",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w600,
                              fontFamily: GoogleFonts.inter().fontFamily,
                            ),
                          ),
                          SizedBox(height: 5.h),
                          Text(
                            "@newdawn.soi",
                            style: TextStyle(
                              color: Color(0xffd9d9d9),
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                              fontFamily: GoogleFonts.inter().fontFamily,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          // 전달받은 이미지 표시
                          Container(
                            width: 259.w,
                            height: 346.h,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: CachedNetworkImage(
                                imageUrl: widget.imageUrl,
                                memCacheWidth: (259 * 2).round(),
                                maxWidthDiskCache: (259 * 2).round(),
                                fit: BoxFit.cover,
                                placeholder:
                                    (context, url) => Container(
                                      color: Colors.grey[800],
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                errorWidget:
                                    (context, url, error) => Container(
                                      color: Colors.grey[800],
                                      child: Icon(
                                        Icons.error,
                                        color: Colors.white,
                                        size: 50,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                          SizedBox(height: 22.h),
                          // 파형과 시간 표시
                          SizedBox(
                            width: 236.w,
                            height: 39.h,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // 파형 표시하는 부분
                                if (widget.waveformData != null &&
                                    widget.waveformData!.isNotEmpty)
                                  Expanded(
                                    child: CustomWaveformWidget(
                                      waveformData: widget.waveformData!,
                                      color: Colors.white,
                                      activeColor: Colors.white,
                                      progress: 0.0,
                                    ),
                                  ),
                                SizedBox(width: 10.w),
                                // 시간을 표시하는 부분
                                Text(
                                  _formatDuration(widget.audioDuration),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: GoogleFonts.inter().fontFamily,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 시간을 포맷팅하는 메서드
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
