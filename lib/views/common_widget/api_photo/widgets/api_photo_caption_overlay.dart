import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import '../first_line_ellipsis_text.dart';
import 'api_photo_circle_avatar.dart';

class ApiPhotoCaptionOverlay extends StatelessWidget {
  const ApiPhotoCaptionOverlay({
    super.key,
    required this.content,
    required this.isExpanded,
    required this.isProfileLoading,
    required this.profileImageUrl,
    required this.profileImageCacheKey,
    required this.onTap,
  });

  final String content;
  final bool isExpanded;
  final bool isProfileLoading;
  final String? profileImageUrl;
  final String? profileImageCacheKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final captionStyle = TextStyle(
      color: Colors.white,
      fontSize: 14.sp,
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w400,
    );

    const avatarSize = 27.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeInOut,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(13.6),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 3.h),
        child: Row(
          crossAxisAlignment: isExpanded
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: avatarSize,
              height: avatarSize,
              child: isProfileLoading
                  ? Shimmer.fromColors(
                      baseColor: Colors.grey[800]!,
                      highlightColor: Colors.grey[600]!,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF2A2A2A),
                        ),
                      ),
                    )
                  : ApiPhotoCircleAvatar(
                      imageUrl: profileImageUrl,
                      size: avatarSize,
                      cacheKey: profileImageCacheKey,
                    ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: isExpanded
                  ? ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.05, 0.95, 1.0],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 6.h),
                          child: Text(content, style: captionStyle),
                        ),
                      ),
                    )
                  : FirstLineEllipsisText(text: content, style: captionStyle),
            ),
          ],
        ),
      ),
    );
  }
}
