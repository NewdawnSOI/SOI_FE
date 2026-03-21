import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:soi/utils/snackbar_utils.dart';

import '../../api/controller/friend_controller.dart';
import '../../api/controller/media_controller.dart';
import '../../api/controller/user_controller.dart';
import '../../api/models/user.dart';

/// ID로 친구 추가 화면
/// 기존 다이얼로그(AddByIdDialog)를 대체하며, 독립된 화면으로 구현합니다.
class AddFriendByIdScreen extends StatefulWidget {
  const AddFriendByIdScreen({super.key});

  @override
  State<AddFriendByIdScreen> createState() => _AddFriendByIdScreenState();
}

class _AddFriendByIdScreenState extends State<AddFriendByIdScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  bool _isSearching = false;
  List<User> _results = [];

  // userId -> status 이렇게 맵 형태로 묶는다.
  Map<int, String> _friendshipStatus = {};
  // userId -> presigned URL 캐시
  final Map<int, String?> _profileUrlCache = {};
  final Map<String, _CachedSearchResult> _searchCache = {};
  final Set<int> _sending = {}; // 요청 버튼 로딩 대상
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.removeListener(_onQueryChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final query = _textController.text.trim();
    _searchGeneration += 1;
    final generation = _searchGeneration;
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _friendshipStatus = {};
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query, generation);
    });
  }

  void _submitSearch(String rawQuery) {
    _debounce?.cancel();
    final query = rawQuery.trim();
    _searchGeneration += 1;
    final generation = _searchGeneration;

    if (query.isEmpty) {
      setState(() {
        _results = [];
        _friendshipStatus = {};
        _isSearching = false;
      });
      return;
    }

    _performSearch(query, generation);
  }

  /// 실제 검색 수행
  ///
  /// Parameters:
  ///   - [String] query: 검색어
  Future<void> _performSearch(String query, int generation) async {
    final cached = _searchCache[query];
    if (cached != null) {
      if (!_isLatestSearch(query, generation)) {
        return;
      }
      setState(() {
        _results = cached.results;
        _friendshipStatus = Map<int, String>.from(cached.status);
        _isSearching = false;
      });
      return;
    }

    // API 호출
    final userController = context.read<UserController>();
    final friendController = context.read<FriendController>();

    // 현재 사용자 ID 가져오기
    final currentUserId = userController.currentUser?.id;

    // 현재 사용자 ID가 없으면 검색 중지
    if (currentUserId == null) {
      debugPrint('로그인된 사용자가 없습니다.');
      setState(() => _isSearching = false);
      return;
    }

    setState(() => _isSearching = true);
    try {
      // UserController의 키워드 검색 사용
      // list는 User 객체의 리스트를 받는다.
      final list = await userController.findUsersByKeyword(query);

      // 본인 제외
      final filteredList = List<User>.unmodifiable(
        list.where((user) => user.id != currentUserId),
      );
      final statusByUserId = <int, String>{};

      // 친구 관계 상태 조회
      if (filteredList.isNotEmpty) {
        final phoneNumbers = filteredList
            .map((u) => u.phoneNumber)
            .where((p) => p.isNotEmpty)
            .toList();

        if (phoneNumbers.isNotEmpty) {
          // 친구 관계 확인 API 호출
          final relations = await friendController.checkFriendRelations(
            userId: currentUserId,
            phoneNumbers: phoneNumbers,
          );
          if (kDebugMode) {
            debugPrint("친구 관계 조회 결과: $relations");
          }

          // 전화번호 -> 상태 매핑을 userId -> 상태로 변환
          final phoneToStatus = <String, String>{};
          for (final relation in relations) {
            // FriendCheck 모델의 statusString 사용
            phoneToStatus[_normalizePhoneNumber(relation.phoneNumber)] =
                relation.statusString;
          }
          // filteredList를 순회하며 상태 매핑 채우기
          for (final user in filteredList) {
            final status =
                phoneToStatus[_normalizePhoneNumber(user.phoneNumber)] ??
                'none';
            statusByUserId[user.id] = status;
          }
          if (kDebugMode) {
            debugPrint("최종 친구 상태 매핑: $statusByUserId");
          }
        }
      }

      if (!_isLatestSearch(query, generation)) {
        return;
      }

      final cachedResult = _CachedSearchResult(
        filteredList,
        Map<int, String>.unmodifiable(statusByUserId),
      );
      _searchCache[query] = cachedResult;

      setState(() {
        _results = filteredList;
        _friendshipStatus = Map<int, String>.from(cachedResult.status);
        _isSearching = false;
      });

      // 프로필 이미지 presigned URL 미리 로드
      unawaited(_preloadProfileUrls(filteredList));
    } catch (e) {
      debugPrint('검색 실패: $e');
      if (!_isLatestSearch(query, generation)) {
        return;
      }
      setState(() {
        _results = [];
        _friendshipStatus = {};
        _isSearching = false;
      });
    }
  }

  /// 프로필 이미지 presigned URL 미리 로드
  Future<void> _preloadProfileUrls(List<User> users) async {
    final mediaController = context.read<MediaController>();
    final usersToResolve = users
        .where(
          (user) =>
              user.profileImageUrlKey?.isNotEmpty == true &&
              !_profileUrlCache.containsKey(user.id),
        )
        .toList(growable: false);

    if (usersToResolve.isEmpty) {
      return;
    }

    final resolvedEntries = await Future.wait<MapEntry<int, String?>?>(
      usersToResolve.map((user) async {
        try {
          final url = await mediaController.getPresignedUrl(
            user.profileImageUrlKey!,
          );
          return MapEntry<int, String?>(user.id, url);
        } catch (e) {
          debugPrint('프로필 이미지 URL 로드 실패: $e');
          return null;
        }
      }),
    );

    if (!mounted) {
      return;
    }

    final resolvedUrls = <int, String?>{};
    for (final entry in resolvedEntries) {
      if (entry == null) {
        continue;
      }
      resolvedUrls[entry.key] = entry.value;
    }

    if (resolvedUrls.isEmpty) {
      return;
    }

    setState(() {
      _profileUrlCache.addAll(resolvedUrls);
    });
  }

  Future<void> _sendFriendRequest(User user) async {
    final userController = context.read<UserController>();
    final friendController = context.read<FriendController>();
    final currentUserId = userController.currentUser?.id;

    if (currentUserId == null) {
      debugPrint('로그인된 사용자가 없습니다.');
      return;
    }

    setState(() => _sending.add(user.id));
    try {
      final result = await friendController.addFriendByNickName(
        requesterId: currentUserId,
        receiverNickName: user.userId,
      );

      if (result != null) {
        setState(() {
          _friendshipStatus[user.id] = 'pending';
        });
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            tr(
              'friends.add_by_id.request_sent',
              context: context,
              namedArgs: {'name': user.name},
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('친구 요청 실패: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          tr('friends.add_by_id.request_failed', context: context),
        );
      }
    } finally {
      if (mounted) setState(() => _sending.remove(user.id));
    }
  }

  /// 검색어와 세대가 현재 최신인지 확인
  /// 세대란?
  /// - 검색이 시작될 때마다 증가하는 숫자.
  /// - 검색 결과가 돌아왔을 때, 이 숫자가 검색어와 함께 최신인지 확인하여, 오래된 검색 결과가 최신 검색 결과를 덮어쓰는 것을 방지합니다.
  bool _isLatestSearch(String query, int generation) {
    return mounted &&
        generation == _searchGeneration &&
        query == _textController.text.trim();
  }

  /// 전화번호에서 숫자만 추출하여 정규화
  String _normalizePhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const double referenceWidth = 393;
    final double scale = screenWidth / referenceWidth;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              tr('friends.add_by_id.title', context: context),
              style: TextStyle(
                color: const Color(0xFFcccccc),
                fontSize: 20,
                fontFamily: GoogleFonts.inter().fontFamily,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Color(0xffcccccc)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(scale),
            Expanded(child: _buildResultsArea()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(double scale) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.sp, 8.sp, 16.sp, 4.sp),
      child: Container(
        height: 44.sp,
        decoration: BoxDecoration(
          color: const Color(0xff1c1c1c),
          borderRadius: BorderRadius.circular(8.sp),
        ),
        child: Row(
          children: [
            SizedBox(width: 12.sp),
            Padding(
              padding: (Platform.isIOS)
                  ? EdgeInsets.only(bottom: 4.sp)
                  : EdgeInsets.zero,
              child: SizedBox(
                width: (19.28).sp,
                height: (19.22).sp,
                child: Icon(Icons.search, color: const Color(0xffcccccc)),
              ),
            ),
            SizedBox(width: 8.sp),
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                style: TextStyle(
                  color: const Color(0xfff9f9f9),
                  fontSize: 15.sp,
                ),
                cursorColor: const Color(0xfff9f9f9),
                decoration: InputDecoration(
                  hintText: tr(
                    'friends.add_by_id.search_hint',
                    context: context,
                  ),
                  hintStyle: TextStyle(
                    color: const Color(0xFFD9D9D9),
                    fontSize: (18.02).sp,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: _submitSearch,
              ),
            ),
            if (_textController.text.isNotEmpty)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.close,
                  color: const Color(0xff9a9a9a),
                  size: 18.sp,
                ),
                onPressed: () {
                  _textController.clear();
                  setState(() {
                    _results = [];
                    _friendshipStatus = {};
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsArea() {
    if (_textController.text.isEmpty) {
      // 초기 상태: 아무 것도 표시하지 않음 (디자인 상 빈 화면)
      return const SizedBox.shrink();
    }
    if (_isSearching) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: Colors.white,
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          tr('friends.add_by_id.not_found', context: context),
          style: TextStyle(color: const Color(0xff9a9a9a), fontSize: 14.sp),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
      itemBuilder: (context, index) {
        final user = _results[index];
        final status = _friendshipStatus[user.id] ?? 'none';
        final isSending = _sending.contains(user.id);
        final profileUrl = _profileUrlCache[user.id];
        return _UserResultTile(
          user: user,
          status: status,
          isSending: isSending,
          profileUrl: profileUrl,
          onAdd: () => _sendFriendRequest(user),
        );
      },
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemCount: _results.length,
    );
  }
}

class _UserResultTile extends StatelessWidget {
  const _UserResultTile({
    required this.user,
    required this.status,
    required this.isSending,
    required this.onAdd,
    this.profileUrl,
  });

  final User user;
  final String status; // 'none' | 'pending' | 'accepted' | 'blocked'
  final bool isSending;
  final VoidCallback onAdd;
  final String? profileUrl;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff1c1c1c),
        borderRadius: BorderRadius.circular(12.r),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      child: Row(
        children: [
          _buildAvatar(devicePixelRatio),
          SizedBox(width: 12.w),
          Expanded(child: _buildTexts()),
          _buildActionButton(context),
        ],
      ),
    );
  }

  Widget _buildAvatar(double devicePixelRatio) {
    final placeholder = Container(
      width: 44.w,
      height: 44.w,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xffd9d9d9),
      ),
      child: Icon(Icons.person, size: 26, color: Colors.white),
    );

    // presigned URL 사용
    if (profileUrl == null || profileUrl!.isEmpty) {
      return placeholder;
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: profileUrl!,
        width: 44.w,
        height: 44.w,
        memCacheWidth: (44 * 2).round(),
        memCacheHeight: (44 * 2).round(),
        maxWidthDiskCache: (44 * 2).round(),
        fit: BoxFit.cover,
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
      ),
    );
  }

  Widget _buildTexts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          user.name.isNotEmpty ? user.name : user.userId,
          style: TextStyle(
            color: const Color(0xfff9f9f9),
            fontSize: 15.sp,
            fontWeight: FontWeight.w500,
            height: 1.1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 4.h),
        Text(
          user.userId,
          style: TextStyle(
            color: const Color(0xff9a9a9a),
            fontSize: 12.sp,
            height: 1.1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context) {
    String label;
    bool enabled = false;
    switch (status) {
      case 'accepted':
        label = tr('friends.add_by_id.status_friend', context: context);
        enabled = false;
        break;
      case 'pending':
        label = tr('friends.add_by_id.status_pending', context: context);
        enabled = false;
        break;
      case 'blocked':
        label = tr('friends.add_by_id.status_blocked', context: context);
        enabled = false;
        break;
      default:
        label = tr('friends.add_by_id.status_add', context: context);
        enabled = true;
    }

    final child = isSending
        ? SizedBox(
            width: 16.w,
            height: 16.w,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Text(
            label,
            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
          );

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: 72.w),
      child: SizedBox(
        height: 32.h,
        child: ElevatedButton(
          onPressed: enabled && !isSending ? onAdd : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: enabled
                ? const Color(0xffffffff)
                : const Color(0xff3a3a3a),
            foregroundColor: enabled
                ? const Color(0xff000000)
                : const Color(0xffc9c9c9),
            disabledBackgroundColor: const Color(0xff3a3a3a),
            disabledForegroundColor: const Color(0xffc9c9c9),
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
            minimumSize: Size(0, 32.h),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            elevation: 0,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 메모이제이션된 검색 결과 구조체
class _CachedSearchResult {
  _CachedSearchResult(this.results, this.status);

  final List<User> results;
  final Map<int, String> status;
}
