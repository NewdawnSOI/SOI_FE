import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/controller/report_controller.dart';
import 'package:soi/api/models/report.dart';
import 'package:soi/api/services/report_service.dart';
import 'package:soi_api_client/api.dart';

class _NoopReportApi extends ReportControllerApi {}

class _FakeReportService extends ReportService {
  _FakeReportService({this.onCreate, this.onGetReports})
    : super(reportApi: _NoopReportApi());

  final Future<bool> Function({
    required int reporterUserId,
    required int targetId,
    required ReportTargetType reportTargetType,
    required ReportType reportType,
    required String reportDetail,
  })?
  onCreate;
  final Future<List<Report>> Function({
    ReportType? reportType,
    ReportStatus? reportStatus,
    ReportTargetType? reportTargetType,
    SortOptionDto? sortOptionDto,
    int? page,
  })?
  onGetReports;

  @override
  Future<bool> createReport({
    required int reporterUserId,
    required int targetId,
    required ReportTargetType reportTargetType,
    required ReportType reportType,
    required String reportDetail,
  }) {
    final handler = onCreate;
    if (handler == null) {
      throw UnimplementedError('onCreate is not configured');
    }
    return handler(
      reporterUserId: reporterUserId,
      targetId: targetId,
      reportTargetType: reportTargetType,
      reportType: reportType,
      reportDetail: reportDetail,
    );
  }

  @override
  Future<List<Report>> getReports({
    ReportType? reportType,
    ReportStatus? reportStatus,
    ReportTargetType? reportTargetType,
    SortOptionDto? sortOptionDto,
    int? page,
  }) {
    final handler = onGetReports;
    if (handler == null) {
      throw UnimplementedError('onGetReports is not configured');
    }
    return handler(
      reportType: reportType,
      reportStatus: reportStatus,
      reportTargetType: reportTargetType,
      sortOptionDto: sortOptionDto,
      page: page,
    );
  }
}

void main() {
  group('ReportController', () {
    test('createReport forwards payload to service', () async {
      int? capturedReporterUserId;
      int? capturedTargetId;
      ReportTargetType? capturedTargetType;
      ReportType? capturedReportType;
      String? capturedDetail;

      final controller = ReportController(
        reportService: _FakeReportService(
          onCreate:
              ({
                required int reporterUserId,
                required int targetId,
                required ReportTargetType reportTargetType,
                required ReportType reportType,
                required String reportDetail,
              }) async {
                capturedReporterUserId = reporterUserId;
                capturedTargetId = targetId;
                capturedTargetType = reportTargetType;
                capturedReportType = reportType;
                capturedDetail = reportDetail;
                return true;
              },
        ),
      );

      final result = await controller.createReport(
        reporterUserId: 4,
        targetId: 8,
        reportTargetType: ReportTargetType.comment,
        reportType: ReportType.spam,
        reportDetail: 'spam',
      );

      expect(result, isTrue);
      expect(capturedReporterUserId, 4);
      expect(capturedTargetId, 8);
      expect(capturedTargetType, ReportTargetType.comment);
      expect(capturedReportType, ReportType.spam);
      expect(capturedDetail, 'spam');
    });

    test('getReports returns service result', () async {
      final controller = ReportController(
        reportService: _FakeReportService(
          onGetReports:
              ({
                ReportType? reportType,
                ReportStatus? reportStatus,
                ReportTargetType? reportTargetType,
                SortOptionDto? sortOptionDto,
                int? page,
              }) async => const [
                Report(id: 1, reportStatus: ReportStatus.pending),
              ],
        ),
      );

      final result = await controller.getReports(
        reportStatus: ReportStatus.pending,
      );

      expect(result, hasLength(1));
      expect(result.first.id, 1);
      expect(result.first.reportStatus, ReportStatus.pending);
    });
  });
}
