import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/models/report.dart';
import 'package:soi/api/services/report_service.dart';
import 'package:soi_api_client/api.dart';

class _FakeReportApi extends ReportControllerApi {
  _FakeReportApi({this.onCreate, this.onFind});

  final Future<ApiResponseDtoBoolean?> Function(ReportCreateRequestDto dto)?
  onCreate;
  final Future<ApiResponseDtoListReportResponseDto?> Function(
    ReportSearchRequestDto dto,
  )?
  onFind;

  @override
  Future<ApiResponseDtoBoolean?> create(
    ReportCreateRequestDto reportCreateRequestDto,
  ) async {
    final handler = onCreate;
    if (handler == null) {
      throw UnimplementedError('onCreate is not configured');
    }
    return handler(reportCreateRequestDto);
  }

  @override
  Future<ApiResponseDtoListReportResponseDto?> find(
    ReportSearchRequestDto reportSearchRequestDto,
  ) async {
    final handler = onFind;
    if (handler == null) {
      throw UnimplementedError('onFind is not configured');
    }
    return handler(reportSearchRequestDto);
  }
}

void main() {
  group('ReportService', () {
    test(
      'createReport maps wrapper enums to generated request enums',
      () async {
        ReportCreateRequestDto? capturedDto;
        final service = ReportService(
          reportApi: _FakeReportApi(
            onCreate: (dto) async {
              capturedDto = dto;
              return ApiResponseDtoBoolean(success: true, data: true);
            },
          ),
        );

        final result = await service.createReport(
          reporterUserId: 3,
          targetId: 9,
          reportTargetType: ReportTargetType.post,
          reportType: ReportType.hate,
          reportDetail: ' abusive content ',
        );

        expect(result, isTrue);
        expect(capturedDto?.reporterUserId, 3);
        expect(capturedDto?.targetId, 9);
        expect(
          capturedDto?.reportTargetType,
          ReportCreateRequestDtoReportTargetTypeEnum.POST,
        );
        expect(
          capturedDto?.reportType,
          ReportCreateRequestDtoReportTypeEnum.HATE,
        );
        expect(capturedDto?.reportDetail, 'abusive content');
      },
    );

    test('getReports maps generated response to domain model', () async {
      final service = ReportService(
        reportApi: _FakeReportApi(
          onFind: (dto) async {
            expect(
              dto.reportStatus,
              ReportSearchRequestDtoReportStatusEnum.PADDING,
            );
            return ApiResponseDtoListReportResponseDto(
              success: true,
              data: [
                ReportResponseDto(
                  id: 10,
                  reporterUserId: 3,
                  targetId: 9,
                  reportTargetType: ReportResponseDtoReportTargetTypeEnum.POST,
                  reportType: ReportResponseDtoReportTypeEnum.HATE,
                  reportStatus: ReportResponseDtoReportStatusEnum.PADDING,
                  reportDetail: 'abusive content',
                ),
              ],
            );
          },
        ),
      );

      final result = await service.getReports(
        reportStatus: ReportStatus.pending,
      );

      expect(result, hasLength(1));
      expect(result.first.id, 10);
      expect(result.first.reportTargetType, ReportTargetType.post);
      expect(result.first.reportType, ReportType.hate);
      expect(result.first.reportStatus, ReportStatus.pending);
    });
  });
}
