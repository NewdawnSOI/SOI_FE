import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AddByIdDialog extends StatefulWidget {
  final double scale;
  final Function(String) onConfirm;

  const AddByIdDialog({
    super.key,
    required this.scale,
    required this.onConfirm,
  });

  @override
  State<AddByIdDialog> createState() => _AddByIdDialogState();

  static void show(
    BuildContext context,
    double scale,
    Function(String) onConfirm,
  ) {
    final TextEditingController idController = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Color(0xff171717).withValues(alpha: 0.8),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Color(0xff323232),
          insetPadding: EdgeInsets.symmetric(horizontal: 40.w),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Container(
                width: 314.w,
                height: 204.h,
                decoration: BoxDecoration(
                  color: Color(0xff323232),
                  borderRadius: BorderRadius.circular(14.2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 제목
                    Text(
                      tr('friends.options.add_by_id_prompt', context: context),
                      style: TextStyle(
                        color: const Color(0xfff9f9f9),
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 24.h),

                    // ID 입력 필드
                    Container(
                      width: 249.w,
                      height: 39.h,
                      decoration: BoxDecoration(
                        color: const Color(0xff323232),
                        borderRadius: BorderRadius.circular(8.89),
                        border: Border.all(
                          color: const Color(0xff5a5a5a),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: idController,
                        style: TextStyle(
                          color: const Color(0xfff9f9f9),
                          fontSize: 16.sp,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 14.h,
                          ),
                        ),
                        cursorColor: Color(0xfff9f9f9),
                      ),
                    ),

                    SizedBox(height: 35.h),

                    // 확인 버튼
                    SizedBox(
                      width: 145.w,
                      height: 48.h,
                      child: ElevatedButton(
                        onPressed: () {
                          final enteredId = idController.text.trim();
                          if (enteredId.isNotEmpty) {
                            Navigator.of(context).pop();
                            onConfirm(enteredId);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xffffffff),
                          foregroundColor: const Color(0xff000000),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.2),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          tr('common.confirm', context: context),
                          style: TextStyle(
                            fontSize: (17.7778).sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _AddByIdDialogState extends State<AddByIdDialog> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
