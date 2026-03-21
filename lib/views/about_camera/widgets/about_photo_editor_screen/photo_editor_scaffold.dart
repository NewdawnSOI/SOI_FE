import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'photo_display_widget.dart';
import 'photo_editor_category_sheet.dart';

class PhotoEditorScaffold extends StatelessWidget {
  const PhotoEditorScaffold({
    super.key,
    required this.isLoading,
    required this.showImmediatePreview,
    required this.errorMessageKey,
    required this.errorMessageArgs,
    required this.isTextOnlyMode,
    required this.textOnlyContent,
    required this.currentFilePath,
    required this.useLocalImage,
    required this.initialImageProvider,
    required this.isVideo,
    required this.isFromCamera,
    required this.onPreviewCancel,
    required this.bottomSheet,
    this.captionInputBar,
  });

  final bool isLoading;
  final bool showImmediatePreview;
  final String? errorMessageKey;
  final Map<String, String>? errorMessageArgs;
  final bool isTextOnlyMode;
  final String textOnlyContent;
  final String? currentFilePath;
  final bool useLocalImage;
  final ImageProvider? initialImageProvider;
  final bool isVideo;
  final bool isFromCamera;
  final Future<void> Function() onPreviewCancel;
  final Widget bottomSheet;
  final Widget? captionInputBar;

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('common.app_name', context: context),
              style: TextStyle(
                color: const Color(0xfff9f9f9),
                fontSize: 20.sp,
                fontFamily: GoogleFonts.inter().fontFamily,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 30.h),
          ],
        ),
        toolbarHeight: 70.h,
        backgroundColor: Colors.black,
      ),
      body: isLoading && !showImmediatePreview
          ? const Center(child: CircularProgressIndicator())
          : errorMessageKey != null
          ? Center(
              child: Text(
                errorMessageKey!,
                style: const TextStyle(color: Colors.white),
              ).tr(namedArgs: errorMessageArgs),
            )
          : Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isTextOnlyMode)
                          _PhotoEditorTextPreviewCard(text: textOnlyContent)
                        else
                          PhotoDisplayWidget(
                            filePath: currentFilePath,
                            useLocalImage: useLocalImage,
                            width: 354.w,
                            height: 500.h,
                            isVideo: isVideo,
                            initialImage: initialImageProvider,
                            onCancel: onPreviewCancel,
                            isFromCamera: isFromCamera,
                          ),
                      ],
                    ),
                  ),
                ),
                if (!isTextOnlyMode && captionInputBar != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: isKeyboardVisible
                        ? 10.h
                        : MediaQuery.of(context).size.height *
                              PhotoEditorCategorySheet.lockedSheetExtent,
                    child: SizedBox(child: captionInputBar),
                  ),
              ],
            ),
      bottomSheet: bottomSheet,
    );
  }
}

class _PhotoEditorTextPreviewCard extends StatelessWidget {
  const _PhotoEditorTextPreviewCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final textTopPadding = 60.sp;

    return Container(
      width: 354.w,
      height: 500.h,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: const Color(0xff2b2b2b), width: 2.0),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.sp, textTopPadding, 20.sp, 20.sp),
              child: SingleChildScrollView(
                child: Text(
                  text,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24.sp,
                    fontFamily: 'Pretendard Variable',
                    fontWeight: FontWeight.w200,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8.sp,
            left: 8.sp,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: SvgPicture.asset(
                'assets/cancel.svg',
                width: 30.08.sp,
                height: 30.08.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
