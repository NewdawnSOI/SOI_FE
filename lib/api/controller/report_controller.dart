import 'package:flutter/material.dart';
import 'package:soi_api_client/api.dart';

import '../models/report.dart';
import '../services/report_service.dart';

class ReportController extends ChangeNotifier {
  ReportController({ReportService? reportService})
    : _reportService = reportService ?? ReportService();

  final ReportService _reportService;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> createReport({
    required int reporterUserId,
    required int targetId,
    required ReportTargetType reportTargetType,
    required ReportType reportType,
    required String reportDetail,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _reportService.createReport(
        reporterUserId: reporterUserId,
        targetId: targetId,
        reportTargetType: reportTargetType,
        reportType: reportType,
        reportDetail: reportDetail,
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('신고 생성 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<List<Report>> getReports({
    ReportType? reportType,
    ReportStatus? reportStatus,
    ReportTargetType? reportTargetType,
    SortOptionDto? sortOptionDto,
    int? page,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _reportService.getReports(
        reportType: reportType,
        reportStatus: reportStatus,
        reportTargetType: reportTargetType,
        sortOptionDto: sortOptionDto,
        page: page,
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('신고 조회 실패: $e');
      _setLoading(false);
      return const [];
    }
  }

  Future<Report?> updateReport({
    required int id,
    required ReportStatus reportStatus,
    String? adminMemo,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _reportService.updateReport(
        id: id,
        reportStatus: reportStatus,
        adminMemo: adminMemo,
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('신고 수정 실패: $e');
      _setLoading(false);
      return null;
    }
  }

  Future<bool> deleteReport(int id) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _reportService.deleteReport(id);
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('신고 삭제 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}
