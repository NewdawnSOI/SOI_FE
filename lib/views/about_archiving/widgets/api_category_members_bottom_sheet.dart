import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:soi/api/controller/media_controller.dart';
import '../../../api/models/category.dart';
import '../../common_widget/user/current_user_image_builder.dart';

/// API 버전 카테고리 멤버들을 보여주는 바텀시트
///
/// 바텀시트가 열릴 때 최신 카테고리 정보를 서버에서 가져와
/// 새로운 presigned URL로 프로필 이미지를 표시합니다.
///
/// Parameters:
///   - [category]: 표시할 카테고리 정보
///   - [onAddFriendPressed]: 친구 추가 버튼이 눌렸을 때 호출되는
class ApiCategoryMembersBottomSheet extends StatefulWidget {
  final Category category;
  final VoidCallback? onAddFriendPressed;

  const ApiCategoryMembersBottomSheet({
    super.key,
    required this.category,
    this.onAddFriendPressed,
  });

  @override
  State<ApiCategoryMembersBottomSheet> createState() =>
      _ApiCategoryMembersBottomSheetState();
}

class _ApiCategoryMembersBottomSheetState
    extends State<ApiCategoryMembersBottomSheet> {
  // presigned URL 캐시
  final Map<String, String> _presignedUrlCache = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 빌드 완료 후 presigned URL 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPresignedUrls();
    });
  }

  /// 모든 프로필 이미지의 presigned URL을 미리 로드
  Future<void> _loadPresignedUrls() async {
    // MediaController 가져오기
    final mediaController = Provider.of<MediaController>(
      context,
      listen: false,
    );

    // 프로필 key 목록
    final profileImageKeys = widget.category.usersProfileKey;

    final unresolvedKeys = profileImageKeys
        .map((key) => key.trim())
        .where((key) => key.isNotEmpty && !_presignedUrlCache.containsKey(key))
        .toList(growable: false);

    if (unresolvedKeys.isNotEmpty) {
      try {
        final urls = await mediaController.getPresignedUrls(unresolvedKeys);
        final resolvedCount = urls.length < unresolvedKeys.length
            ? urls.length
            : unresolvedKeys.length;
        for (var index = 0; index < resolvedCount; index++) {
          final url = urls[index];
          if (url.isEmpty) {
            continue;
          }
          _presignedUrlCache[unresolvedKeys[index]] = url;
        }
      } catch (e) {
        debugPrint('[ApiCategoryMembersBottomSheet] presigned URL 로드 실패: $e');
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 인덱스별 즉시 렌더용 URL을 읽어 프로필 이미지를 빠르게 보여줍니다.
  String? _profileImageUrlAt(int index) {
    if (index < 0 || index >= widget.category.usersProfileUrl.length) {
      return null;
    }
    final normalized = widget.category.usersProfileUrl[index].trim();
    return normalized.isEmpty ? null : normalized;
  }

  /// 인덱스별 key를 읽어 fresh presigned URL 재발급과 캐시 키 계산에 사용합니다.
  String? _profileImageKeyAt(int index) {
    if (index < 0 || index >= widget.category.usersProfileKey.length) {
      return null;
    }
    final normalized = widget.category.usersProfileKey[index].trim();
    return normalized.isEmpty ? null : normalized;
  }

  /// key로 갱신된 URL이 있으면 우선 사용하고, 없으면 즉시 사용 가능한 URL을 그대로 사용합니다.
  String _resolveDisplayProfileUrl(int index) {
    final key = _profileImageKeyAt(index);
    final resolvedUrl = key == null ? null : _presignedUrlCache[key];
    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      return resolvedUrl;
    }

    return _profileImageUrlAt(index) ?? '';
  }

  /// key가 있을 때는 그것을 캐시 식별자로 사용해 presigned URL이 갱신돼도 같은 이미지를 재사용합니다.
  String? _resolveProfileCacheKey(int index) {
    final key = _profileImageKeyAt(index);
    if (key != null) {
      return key;
    }

    final profileUrl = _profileImageUrlAt(index);
    if (profileUrl == null) {
      return null;
    }

    final uri = Uri.tryParse(profileUrl);
    if (uri == null || !uri.hasScheme) {
      return null;
    }

    final normalizedPath = uri.path.trim();
    if (normalizedPath.isEmpty) {
      return null;
    }

    final normalizedHost = uri.host.trim();
    return normalizedHost.isEmpty
        ? normalizedPath
        : '$normalizedHost$normalizedPath';
  }

  @override
  Widget build(BuildContext context) {
    // 멤버 총 수
    final totalMemberCount = widget.category.totalUserCount;

    // 멤버 닉네임 목록
    final memberNickNames = widget.category.nickNames;
    final hasImmediateProfileUrls = widget.category.usersProfileUrl.any(
      (url) => url.trim().isNotEmpty,
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 7.h),
          // 핸들바
          Container(
            width: 56.w,
            height: 2.9.h,
            decoration: BoxDecoration(
              color: const Color(0xFFCCCCCC),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),

          SizedBox(height: 24.h),

          // 멤버 목록 (로딩 중이면 shimmer 표시)
          _isLoading && !hasImmediateProfileUrls
              ? _buildLoadingGrid(totalMemberCount)
              : _buildMembersGrid(context, totalMemberCount, memberNickNames),

          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  /// 로딩 중 그리드 (shimmer)
  Widget _buildLoadingGrid(int totalMemberCount) {
    final itemCount = totalMemberCount + 1;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.8,
          mainAxisSpacing: 16.h,
          crossAxisSpacing: 12.w,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == totalMemberCount) {
            return _buildAddFriendButton(context);
          }
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMemberShimmer(),
              SizedBox(height: (5.86).h),
              Container(
                width: 40.w,
                height: 12.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 멤버 그리드 위젯
  Widget _buildMembersGrid(
    BuildContext context,
    int totalMemberCount,
    List<String> memberNickNames,
  ) {
    // 친구 추가 버튼 포함 총 아이템 수
    // +1 친구 추가 버튼 --> 추가하기 버튼을 위해서
    final itemCount = totalMemberCount + 1;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.8,
          mainAxisSpacing: 16.h,
          crossAxisSpacing: 12.w,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // 마지막 아이템은 친구 추가 버튼
          if (index == totalMemberCount) {
            return _buildAddFriendButton(context);
          }

          // 멤버 닉네임을 index별로 순서대로 가지고 오기
          final memberNickName = index < memberNickNames.length
              ? memberNickNames[index]
              : '';
          final profileUrl = _resolveDisplayProfileUrl(index);
          final cacheKey = _resolveProfileCacheKey(index);
          final profileImageKey = _profileImageKeyAt(index);

          return _buildMemberItem(
            profileUrl,
            memberNickName,
            cacheKey: cacheKey,
            profileImageKey: profileImageKey,
          );
        },
      ),
    );
  }

  /// 개별 멤버 아이템
  Widget _buildMemberItem(
    String profileUrl,
    String memberNickName, {
    String? cacheKey,
    String? profileImageKey,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 프로필 이미지
        _CategoryMemberAvatar(
          memberNickname: memberNickName,
          fallbackProfileUrl: profileUrl,
          fallbackCacheKey: cacheKey,
          fallbackProfileKey: profileImageKey,
          isLoading: _isLoading,
          shimmerBuilder: _buildMemberShimmer,
          fallbackBuilder: _buildBasicMemberIcon,
        ),

        SizedBox(height: (5.86).h),

        // 이름 (임시)
        Text(
          memberNickName,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            fontFamily: 'Pretendard',
            letterSpacing: -0.4,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// 친구 추가 버튼
  Widget _buildAddFriendButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 바텀시트 닫기
        Navigator.pop(context);

        // 친구 추가 콜백 호출 (다음 프레임에서 실행)
        if (widget.onAddFriendPressed != null) {
          Future.microtask(widget.onAddFriendPressed!);
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // + 버튼
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFffffff),
            ),
            child: Center(
              child: Image.asset(
                'assets/plus_icon.png',
                width: 25.5,
                height: 25.5,
                fit: BoxFit.cover,
              ),
            ),
          ),

          SizedBox(height: 8.h),

          // 텍스트
          Text(
            'category.members.add',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              fontFamily: 'Pretendard',
            ),
            textAlign: TextAlign.center,
          ).tr(),
        ],
      ),
    );
  }

  /// Shimmer 로딩 위젯
  Widget _buildMemberShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade700,
      highlightColor: Colors.grey.shade500,
      child: Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
      ),
    );
  }

  /// 기본 프로필 이미지 (fallback)
  Widget _buildBasicMemberIcon() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFd9d9d9),
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 44),
    );
  }
}

/// 멤버 바텀시트의 아바타 셀만 현재 사용자 이미지 selector를 구독해 부분 갱신합니다.
class _CategoryMemberAvatar extends StatelessWidget {
  const _CategoryMemberAvatar({
    required this.memberNickname,
    required this.fallbackProfileUrl,
    required this.fallbackCacheKey,
    required this.fallbackProfileKey,
    required this.isLoading,
    required this.shimmerBuilder,
    required this.fallbackBuilder,
  });

  final String memberNickname;
  final String fallbackProfileUrl;
  final String? fallbackCacheKey;
  final String? fallbackProfileKey;
  final bool isLoading;
  final Widget Function() shimmerBuilder;
  final Widget Function() fallbackBuilder;

  @override
  Widget build(BuildContext context) {
    return CurrentUserImageBuilder(
      imageKind: CurrentUserImageKind.profile,
      targetUserHandle: memberNickname,
      fallbackImageUrl: fallbackProfileUrl,
      fallbackImageKey: fallbackProfileKey,
      builder: (context, imageUrl, cacheKey) {
        final profileUrl = imageUrl?.trim() ?? '';
        final resolvedCacheKey = cacheKey ?? fallbackCacheKey;
        final shouldShowShimmer =
            isLoading || (profileUrl.isEmpty && resolvedCacheKey != null);

        return ClipOval(
          child: SizedBox(
            width: 60,
            height: 60,
            child: profileUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: profileUrl,
                    cacheKey: resolvedCacheKey,
                    useOldImageOnUrlChange: resolvedCacheKey != null,
                    fit: BoxFit.cover,
                    memCacheWidth: (60 * 4).round(),
                    memCacheHeight: (60 * 4).round(),
                    maxWidthDiskCache: (60 * 4).round(),
                    placeholder: (context, url) => shimmerBuilder(),
                    errorWidget: (context, url, error) {
                      debugPrint(
                        '[ApiCategoryMembersBottomSheet] 이미지 로드 에러: $error',
                      );
                      return fallbackBuilder();
                    },
                  )
                : shouldShowShimmer
                ? shimmerBuilder()
                : fallbackBuilder(),
          ),
        );
      },
    );
  }
}

/// ApiCategoryMembersBottomSheet를 표시하는 헬퍼 함수
void showApiCategoryMembersBottomSheet(
  BuildContext context, {
  required Category category,
  VoidCallback? onAddFriendPressed,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => ApiCategoryMembersBottomSheet(
      category: category,
      onAddFriendPressed: onAddFriendPressed,
    ),
  );
}
