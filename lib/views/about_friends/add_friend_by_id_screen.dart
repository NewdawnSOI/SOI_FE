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

  /// focusNode는 텍스트 필드의 포커스 상태를 관리하는 객체입니다. 검색어 입력란에 포커스를 주거나 해제할 때 사용됩니다.
  final FocusNode _focusNode = FocusNode();

  /// 디바운스 타이머: 사용자가 검색어 입력을 멈춘 후 일정 시간(400ms) 동안 추가 입력이 없으면 실제 검색을 수행합니다.
  /// 이를 통해 사용자가 입력하는 동안 불필요한 API 호출을 방지하고, 입력이 완료된 후에만 검색을 수행하여 효율성을 높입니다.
  Timer? _debounce;

  /// 현재 검색 중인지 여부를 나타냅니다.
  bool _isSearching = false;

  /// 검색 결과로 반환된 사용자 목록입니다.
  /// 검색 결과가 있을 때마다 업데이트되며, 사용자에게 표시됩니다.
  List<User> _results = [];

  /// userId에 대한 친구 상태를 매핑합니다.
  /// 예시: {123: 'accepted', 456: 'pending', 789: 'none'}
  Map<int, String> _friendshipStatus = {};

  /// userId에 대한 프로필 이미지를 미리 로드하여 캐싱(맵을 통해서 관리)합니다.
  /// 검색 결과에 프로필 이미지가 포함된 경우, presigned URL을 미리 로드하여 빠르게 이미지를 표시할 수 있도록 지원합니다.
  /// 예시: {123: 'https://presigned.url/to/profile/image.jpg'}
  final Map<int, String?> _profileUrlCache = {};

  /// 검색어에 대한 **검색 결과**와 **친구 상태**를 캐싱하여, 동일 검색어에 대한 빠른 결과 표시를 지원합니다.
  /// 검색어가 동일할 때 API 호출을 방지하고, 빠르게 결과를 표시할 수 있도록 합니다.
  /// 예시: {'john': _CachedSearchResult([...], {123: 'accepted', 456: 'pending'})}
  final Map<String, _CachedSearchResult> _searchCache = {};

  /// 현재 친구 요청을 **보내는 중**인 userId 집합입니다.
  /// 중복 요청 방지 및 로딩 상태 표시를 위해 사용합니다.
  /// 예시: {456, 789} - userId 456과 789에 대한 친구 요청이 현재 진행 중임을 나타냅니다.
  final Set<int> _sending = {};

  /// 검색 세대를 관리하는 변수입니다.
  ///
  /// 검색 세대란?
  /// - 검색이 시작될 때마다 증가하는 숫자.
  /// - 검색 결과가 돌아왔을 때, 이 숫자가 검색어와 함께 최신인지 확인하여, 오래된 검색 결과가 최신 검색 결과를 덮어쓰는 것을 방지합니다.
  ///
  /// 동작 방식
  /// 1. 사용자가 검색어를 입력할 때마다 `_searchGeneration`이 증가합니다.
  /// 2. 검색 결과가 돌아왔을 때, 해당 결과가 현재 검색어와 세대에 해당하는지 확인합니다.
  /// 3. 만약 검색어가 변경되었거나 세대가 일치하지 않으면, 해당 검색 결과는 무시됩니다.
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

  /// 검색어 변경 시 호출되는 리스너
  /// 검색어 입력이 끝난 후 일정 시간(400ms) 동안 추가 입력이 없으면 실제 검색을 수행합니다.
  /// 이를 통해 사용자가 입력하는 동안 불필요한 API 호출을 방지하고, 입력이 완료된 후에만 검색을 수행하여 효율성을 높입니다.
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

  /// 검색어를 제출할 때 호출되는 메서드
  /// [rawQuery]는 사용자가 입력한 원본 검색어입니다. 이 메서드는 트림된 검색어를 사용하여 검색을 수행합니다.
  ///
  /// Parameters:
  ///   - [String] query: 검색어
  void _submitSearch(String rawQuery) {
    _debounce?.cancel();
    final query = rawQuery.trim(); // 트림된 검색어 사용

    // 검색 세대 증가
    // 검색이 시작될 때마다 세대가 증가하여, 검색 결과가 돌아왔을 때 해당 결과가 최신 검색어에 대한 것인지 확인할 수 있도록 합니다.
    _searchGeneration += 1;

    // 현재 검색 세대를 저장
    final generation = _searchGeneration;

    if (query.isEmpty) {
      setState(() {
        _results = [];
        _friendshipStatus = {};
        _isSearching = false;
      });
      return;
    }

    // 실제 검색 수행
    // 검색어와 세대를 함께 전달하여, 검색 결과가 돌아왔을 때 해당 결과가 최신 검색어에 대한 것인지 확인할 수 있도록 합니다.
    _performSearch(query, generation);
  }

  /// 실제 검색 수행
  ///
  /// Parameters:
  ///   - [String] query: 검색어
  Future<void> _performSearch(String query, int generation) async {
    // 검색어에 대한 캐시된 결과가 있는지 확인합니다.
    // 캐시된 결과가 있으면 API 호출 없이 빠르게 결과를 표시할 수 있습니다.
    final cached = _searchCache[query];

    // 캐시된 결과가 있고, 현재 검색 세대와 일치하는 경우에만 캐시된 결과를 사용합니다.
    if (cached != null) {
      // 검색 세대와 검색어가 현재 최신인지 확인하여,
      // 오래된 검색 결과가 최신 검색 결과를 덮어쓰는 것을 방지합니다.
      if (!_isLatestSearch(query, generation)) {
        return;
      }
      setState(() {
        _results = cached.results; // 캐시된 검색 결과 사용 --> API 호출 없이 빠르게 결과 표시

        // 캐시된 친구 상태 사용 --> API 호출 없이 빠르게 결과 표시
        _friendshipStatus = Map<int, String>.from(cached.status);

        // 검색이 완료된 상태로 업데이트
        _isSearching = false;
      });
      return;
    }

    // controller 인스턴스 가져오기
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

    setState(() => _isSearching = true); // 검색 중 상태로 업데이트

    try {
      // UserController의 키워드 검색 사용
      // list는 User 객체의 리스트를 받는다.
      final list = await userController.findUsersByKeyword(query);

      // 검색 결과에서 현재 사용자 제외
      // searchResultWOCurrentUser: 검색 결과에서 현재 사용자를 제외한 User 객체의 리스트입니다.
      final searchResultWOCurrentUser = List<User>.unmodifiable(
        list.where((user) => user.id != currentUserId),
      );

      // 친구 상태 매핑을 위한 Map 초기화
      final statusByUserId = <int, String>{};

      // 검색 결과가 비어있지 않은 경우에만 친구 관계 확인 API 호출
      if (searchResultWOCurrentUser.isNotEmpty) {
        // 전화번호 정규화 및 중복 제거
        // searchResultWOCurrentUser에서 각 사용자의 전화번호를 추출하여 정규화한 후,
        // 중복을 제거하여 고유한 전화번호 List를 생성합니다.
        final phoneNumbers = searchResultWOCurrentUser
            .map((u) => u.phoneNumber)
            .where((p) => p.isNotEmpty)
            .toList();

        // 전화번호가 있는 사용자에 대해서만 친구 관계 확인 API를 호출하여, 불필요한 API 호출을 방지합니다.
        if (phoneNumbers.isNotEmpty) {
          // 친구 관계 확인 API 호출
          // relations는 친구 관계 조회 결과로, 각 전화번호에 대한 친구 상태를 포함합니다.
          final relations = await friendController.checkFriendRelations(
            userId: currentUserId,
            phoneNumbers: phoneNumbers,
          );
          if (kDebugMode) {
            debugPrint("친구 관계 조회 결과: $relations");
          }

          // 정규화된 전화번호에 대해서 친구 상태를 매핑합니다.
          Map<String, String> phoneToStatus = <String, String>{};

          // 친구 관계 조회 결과를 순회하며, 전화번호를 정규화하여 상태 매핑을 채웁니다.
          for (final relation in relations) {
            // 전화번호 정규화를 통해 일관된 키로 상태 매핑을 채웁니다.
            // 예시: {'01012345678': 'accepted', '01098765432': 'pending'}
            phoneToStatus[_normalizePhoneNumber(relation.phoneNumber)] =
                relation.statusString;
          }
          // 자신을 제외한 검색 결과를 순회하여서 user를 가져와서 전화번호 정규화에 대한 친구 상태를 매핑하여 친구 관계 리스트에 저장합니다.
          for (final user in searchResultWOCurrentUser) {
            // 전화번호 정규화에 대한 친구 상태를 매핑하여 친구 관계 리스트에 저장합니다.
            final relationShipStatus =
                phoneToStatus[_normalizePhoneNumber(user.phoneNumber)] ??
                'none';

            // 친구 상태(status에 저장되어있음)에 대해서 userId를 키로 하는 매핑을 채웁니다.
            // 예시: {123: 'accepted', 456: 'pending', 789: 'none'}
            statusByUserId[user.id] = relationShipStatus;
          }
          if (kDebugMode) {
            debugPrint("최종 친구 상태 매핑: $statusByUserId");
          }
        }
      }

      // 검색 결과가 돌아왔을 때, 검색어와 세대가 현재 최신인지 확인하여,
      // 오래된 검색 결과가 최신 검색 결과를 덮어쓰는 것을 방지합니다.
      // false인 경우, 검색어가 변경되었거나 세대가 일치하지 않으므로, 해당 검색 결과는 무시됩니다.
      if (!_isLatestSearch(query, generation)) {
        return;
      }

      // 검색 결과와 친구 상태를 캐싱하여, 동일 검색어에 대한 빠른 결과 표시를 지원합니다.
      //
      // Map<int, String>.unmodifiable(statusByUserId)
      // - 친구 상태 매핑을 **불변 맵**으로 만들어 캐시에 저장합니다.
      // - 이를 통해 캐시된 친구 상태가 외부에서 변경되는 것을 방지합니다.
      final cachedResult = _CachedSearchResult(
        searchResultWOCurrentUser,
        Map<int, String>.unmodifiable(statusByUserId),
      );

      // 검색어에 대한 검색 결과와 친구 상태를 캐싱하여, 동일 검색어에 대한 빠른 결과 표시를 지원합니다.
      _searchCache[query] = cachedResult;

      setState(() {
        _results = searchResultWOCurrentUser;
        _friendshipStatus = Map<int, String>.from(cachedResult.status);
        _isSearching = false;
      });

      // 프로필 이미지 presigned URL 미리 로드
      unawaited(_preloadProfileUrls(searchResultWOCurrentUser));
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
            // "ID로 친구 추가" 텍스트
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
        // 뒤로 가기 아이콘 색상
        iconTheme: const IconThemeData(color: Color(0xffcccccc)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(scale), // 검색 바 빌드
            Expanded(child: _buildResultsArea()), // 검색 결과 영역 빌드
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
