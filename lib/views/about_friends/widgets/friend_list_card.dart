import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../controllers/friend_controller.dart';
import '../friend_list_add_screen.dart';

class FriendListCard extends StatelessWidget {
  final double scale;

  const FriendListCard({super.key, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Consumer<FriendController>(
      builder: (context, friendController, child) {
        final friends = friendController.friends;

        return SizedBox(
          width: 354.w,
          child: Card(
            clipBehavior: Clip.antiAliasWithSaveLayer,
            color: const Color(0xff1c1c1c),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                friends.isEmpty
                    ? SizedBox(
                      height: 132.h,
                      child: Center(
                        child: Text(
                          '아직 친구가 없습니다',
                          style: TextStyle(
                            color: const Color(0xff666666),
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 친구들 리스트 (세로 리스트)
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: friends.length,
                          itemBuilder: (context, index) {
                            final friend = friends[index];
                            return Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 18.w,
                                vertical: 8.h,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // 프로필 이미지 (고정 크기)
                                  CircleAvatar(
                                    radius: (22),
                                    backgroundColor: const Color(0xff323232),
                                    backgroundImage:
                                        friend.profileImageUrl != null
                                            ? NetworkImage(
                                              friend.profileImageUrl!,
                                            )
                                            : null,
                                    child:
                                        friend.profileImageUrl == null
                                            ? Text(
                                              friend.id.isNotEmpty
                                                  ? friend.id[0]
                                                  : '?',
                                              style: TextStyle(
                                                color: const Color(0xfff9f9f9),
                                                fontSize: 15.sp,
                                                fontWeight: FontWeight.w600,
                                                height: 1.1,
                                              ),
                                            )
                                            : null,
                                  ),
                                  SizedBox(width: 9.w),
                                  // 이름 + 서브텍스트 영역
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          friend.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: const Color(0xffd9d9d9),
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        Text(
                                          friend.id,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: const Color(0xffd9d9d9),
                                            fontSize: 10.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // 더보기 링크 (친구가 10명 이상일 때)
                        GestureDetector(
                          onTap: () {
                            // 친구 목록 전체 화면으로 이동
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (context) => const FriendListAddScreen(),
                              ),
                            );
                          },
                          child: Column(
                            children: [
                              Divider(height: 1, color: Color(0xff1c1c1c)),
                              SizedBox(height: (12).h),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add, size: (18).sp),
                                  SizedBox(width: (8).w),
                                  Text(
                                    '더보기',
                                    style: TextStyle(
                                      color: const Color(0xffd9d9d9),
                                      fontSize: (16).sp,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: (12).h),
                            ],
                          ),
                        ),
                      ],
                    ),
          ),
        );
      },
    );
  }
}
