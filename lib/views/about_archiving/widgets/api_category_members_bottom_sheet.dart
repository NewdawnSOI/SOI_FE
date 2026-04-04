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

typedef _CategoryMemberProfile = ({String url, String? cacheKey, String? key});

/// 카테고리 멤버 목록과 추가 액션을 동일한 바텀시트에서 보여줍니다.
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

/// 멤버 프로필 URL 준비 상태와 그리드 렌더링을 함께 관리하는 바텀시트 상태입니다.
class _ApiCategoryMembersBottomSheetState
    extends State<ApiCategoryMembersBottomSheet> {
  static const double _avatarSize = 60;
  static const double _avatarIconSize = 44;
  static const int _gridCrossAxisCount = 4;

  final Map<String, String> _presignedUrlCache = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadPresignedUrls());
    });
  }

  /// 멤버 프로필 key에 대응하는 presigned URL을 한 번에 받아 캐시에 저장합니다.
  Future<void> _loadPresignedUrls() async {
    final mediaController = Provider.of<MediaController>(
      context,
      listen: false,
    );
    final unresolvedKeys = widget.category.usersProfileKey
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

  /// 인덱스 위치의 멤버 프로필 정보를 정규화해 즉시 URL과 캐시 키를 함께 제공합니다.
  _CategoryMemberProfile _profileAt(int index) {
    final key = _valueAt(widget.category.usersProfileKey, index);
    final immediateUrl = _valueAt(widget.category.usersProfileUrl, index);
    final resolvedUrl = key == null ? null : _presignedUrlCache[key];

    return (
      url: resolvedUrl?.isNotEmpty == true ? resolvedUrl! : immediateUrl ?? '',
      cacheKey: key ?? _cacheKeyFromUrl(immediateUrl),
      key: key,
    );
  }

  /// 리스트 범위를 넘지 않는 값만 꺼내고 공백 문자열은 null로 정규화합니다.
  String? _valueAt(List<String> values, int index) {
    if (index < 0 || index >= values.length) {
      return null;
    }

    final normalized = values[index].trim();
    return normalized.isEmpty ? null : normalized;
  }

  /// key가 없는 외부 URL은 host/path 기반 캐시 키로 정규화합니다.
  String? _cacheKeyFromUrl(String? profileUrl) {
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
    final totalMemberCount = widget.category.totalUserCount;
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
          Container(
            width: 56.w,
            height: 2.9.h,
            decoration: BoxDecoration(
              color: const Color(0xFFCCCCCC),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),

          SizedBox(height: 24.h),

          _isLoading && !hasImmediateProfileUrls
              ? _buildLoadingGrid(totalMemberCount)
              : _buildMembersGrid(totalMemberCount),

          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  /// 멤버 셀과 추가 버튼이 같은 레이아웃 규칙을 쓰도록 공통 그리드를 조립합니다.
  Widget _buildGrid({
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _gridCrossAxisCount,
          childAspectRatio: 0.8,
          mainAxisSpacing: 16.h,
          crossAxisSpacing: 12.w,
        ),
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      ),
    );
  }

  /// 프로필 URL이 준비되기 전에는 셀 모양을 유지한 shimmer 그리드를 보여줍니다.
  Widget _buildLoadingGrid(int totalMemberCount) {
    final itemCount = totalMemberCount + 1;

    return _buildGrid(
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
    );
  }

  /// 카테고리 멤버와 추가 버튼을 같은 그리드에서 순서대로 렌더링합니다.
  Widget _buildMembersGrid(int totalMemberCount) {
    final itemCount = totalMemberCount + 1;

    return _buildGrid(
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == totalMemberCount) {
          return _buildAddFriendButton(context);
        }

        final memberNickname = _valueAt(widget.category.nickNames, index) ?? '';
        final profile = _profileAt(index);

        return _buildMemberItem(
          memberNickname: memberNickname,
          profile: profile,
        );
      },
    );
  }

  /// 개별 멤버 셀은 아바타와 닉네임만 책임지도록 단순하게 유지합니다.
  Widget _buildMemberItem({
    required String memberNickname,
    required _CategoryMemberProfile profile,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CategoryMemberAvatar(
          memberNickname: memberNickname,
          fallbackProfileUrl: profile.url,
          fallbackCacheKey: profile.cacheKey,
          fallbackProfileKey: profile.key,
          isLoading: _isLoading,
          shimmerBuilder: _buildMemberShimmer,
          fallbackBuilder: _buildBasicMemberIcon,
        ),
        SizedBox(height: (5.86).h),
        Text(
          memberNickname,
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

  /// 친구 추가 버튼은 시트를 닫은 뒤 상위 액션을 다음 마이크로태스크에서 실행합니다.
  Widget _buildAddFriendButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);

        if (widget.onAddFriendPressed != null) {
          Future.microtask(widget.onAddFriendPressed!);
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: _avatarSize,
            height: _avatarSize,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFffffff),
            ),
            child: Center(
              child: Image.asset(
                'assets/plus_icon.png',
                width: 25.5.w,
                height: 25.5.w,
                fit: BoxFit.cover,
              ),
            ),
          ),

          SizedBox(height: 8.h),

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

  /// 프로필 이미지가 준비되기 전의 원형 placeholder를 제공합니다.
  Widget _buildMemberShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade700,
      highlightColor: Colors.grey.shade500,
      child: Container(
        width: _avatarSize,
        height: _avatarSize,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
      ),
    );
  }

  /// 이미지가 없거나 로드 실패했을 때 공통 기본 아바타를 보여줍니다.
  Widget _buildBasicMemberIcon() {
    return Container(
      width: _avatarSize,
      height: _avatarSize,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFd9d9d9),
      ),
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: _avatarIconSize,
      ),
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
            width: _ApiCategoryMembersBottomSheetState._avatarSize,
            height: _ApiCategoryMembersBottomSheetState._avatarSize,
            child: profileUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: profileUrl,
                    cacheKey: resolvedCacheKey,
                    useOldImageOnUrlChange: resolvedCacheKey != null,
                    fit: BoxFit.cover,
                    memCacheWidth:
                        (_ApiCategoryMembersBottomSheetState._avatarSize * 3)
                            .round(),

                    maxWidthDiskCache:
                        (_ApiCategoryMembersBottomSheetState._avatarSize * 3)
                            .round(),
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

/// 카테고리 멤버 시트를 공통 옵션으로 띄워 호출부를 단순하게 유지합니다.
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
