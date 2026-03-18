import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../api/models/report.dart';

class ReportResult {
  final ReportType reportType;
  final String reasonLabel;
  final String? detail;

  const ReportResult({
    required this.reportType,
    required this.reasonLabel,
    this.detail,
  });
}

extension ReportResultMapper on ReportResult {
  String toReportDetailPayload() {
    final normalizedReason = reasonLabel.trim();
    final normalizedDetail = detail?.trim();

    if (normalizedDetail == null || normalizedDetail.isEmpty) {
      return normalizedReason;
    }

    return '$normalizedReason\n$normalizedDetail';
  }
}

class ReportBottomSheet {
  static Future<ReportResult?> show(BuildContext context) async {
    final reasons = <String, ReportType>{
      'report.reasons.spam': ReportType.spam,
      'report.reasons.hate': ReportType.hate,
      'report.reasons.inappropriate': ReportType.illegal,
      'report.reasons.other': ReportType.etc,
    };
    String? selectedReasonKey;
    final detailController = TextEditingController();

    return showModalBottomSheet<ReportResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF323232),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
            ),
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            child: StatefulBuilder(
              builder: (context, setState) {
                final canSubmit = selectedReasonKey != null;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5A5A5A),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      tr('common.report', context: context),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                    SizedBox(height: 12.h),
                    DropdownButtonFormField<String>(
                      initialValue: selectedReasonKey,
                      dropdownColor: const Color(0xFF323232),
                      iconEnabledColor: Colors.white,
                      items: reasons.keys
                          .map(
                            (reasonKey) => DropdownMenuItem(
                              value: reasonKey,
                              child: Text(
                                tr(reasonKey, context: context),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.sp,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => selectedReasonKey = value);
                      },
                      decoration: InputDecoration(
                        labelText: tr('report.reason_label', context: context),
                        labelStyle: TextStyle(
                          color: const Color(0xFFB0B0B0),
                          fontSize: 13.sp,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color(0xFF5A5A5A),
                          ),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: detailController,
                      maxLines: 3,
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                      decoration: InputDecoration(
                        hintText: tr('report.detail_hint', context: context),
                        hintStyle: TextStyle(
                          color: const Color(0xFFB0B0B0),
                          fontSize: 13.sp,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color(0xFF5A5A5A),
                          ),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    SizedBox(
                      width: double.infinity,
                      height: 40.h,
                      child: ElevatedButton(
                        onPressed: canSubmit
                            ? () {
                                final detail = detailController.text.trim();
                                Navigator.of(sheetContext).pop(
                                  ReportResult(
                                    reportType: reasons[selectedReasonKey!]!,
                                    reasonLabel: tr(
                                      selectedReasonKey!,
                                      context: context,
                                    ),
                                    detail: detail.isEmpty ? null : detail,
                                  ),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: const Color(0xFF5A5A5A),
                          disabledForegroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          tr('report.submit', context: context),
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Pretendard',
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
