import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:soi_api_client/api.dart';

import '../api_client.dart';
import '../api_exception.dart';
import '../models/report.dart';

class ReportService {
  ReportService({ReportControllerApi? reportApi})
    : _reportApi = reportApi ?? SoiApiClient.instance.reportApi;

  final ReportControllerApi _reportApi;

  Future<bool> createReport({
    required int reporterUserId,
    required int targetId,
    required ReportTargetType reportTargetType,
    required ReportType reportType,
    required String reportDetail,
  }) async {
    try {
      final response = await _reportApi.create(
        ReportCreateRequestDto(
          reporterUserId: reporterUserId,
          targetId: targetId,
          reportTargetType: _toCreateTargetTypeEnum(reportTargetType),
          reportType: _toCreateReportTypeEnum(reportType),
          reportDetail: reportDetail.trim(),
        ),
      );

      if (response == null) {
        throw const DataValidationException(message: '신고 생성 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '신고 생성 실패');
      }

      return response.data ?? false;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '신고 생성 실패: $e', originalException: e);
    }
  }

  Future<List<Report>> getReports({
    ReportType? reportType,
    ReportStatus? reportStatus,
    ReportTargetType? reportTargetType,
    SortOptionDto? sortOptionDto,
    int? page,
  }) async {
    try {
      final response = await _reportApi.find(
        ReportSearchRequestDto(
          reportType: _toSearchReportTypeEnum(reportType),
          reportStatus: _toSearchReportStatusEnum(reportStatus),
          reportTargetType: _toSearchTargetTypeEnum(reportTargetType),
          sortOptionDto: sortOptionDto,
          page: page,
        ),
      );

      if (response == null) {
        return const [];
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '신고 조회 실패');
      }

      return response.data.map(Report.fromDto).toList();
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '신고 조회 실패: $e', originalException: e);
    }
  }

  Future<Report?> updateReport({
    required int id,
    required ReportStatus reportStatus,
    String? adminMemo,
  }) async {
    try {
      final response = await _reportApi.update2(
        ReportUpdateReqDto(
          id: id,
          reportStatus: _toUpdateReportStatusEnum(reportStatus),
          adminMemo: adminMemo?.trim(),
        ),
      );

      if (response == null) {
        return null;
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '신고 수정 실패');
      }

      final dto = response.data;
      return dto == null ? null : Report.fromDto(dto);
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '신고 수정 실패: $e', originalException: e);
    }
  }

  Future<bool> deleteReport(int id) async {
    try {
      final response = await _reportApi.delete1(id);

      if (response == null) {
        throw const DataValidationException(message: '신고 삭제 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '신고 삭제 실패');
      }

      return response.data ?? false;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '신고 삭제 실패: $e', originalException: e);
    }
  }

  ReportCreateRequestDtoReportTargetTypeEnum _toCreateTargetTypeEnum(
    ReportTargetType value,
  ) {
    switch (value) {
      case ReportTargetType.user:
        return ReportCreateRequestDtoReportTargetTypeEnum.USER;
      case ReportTargetType.post:
        return ReportCreateRequestDtoReportTargetTypeEnum.POST;
      case ReportTargetType.comment:
        return ReportCreateRequestDtoReportTargetTypeEnum.COMMENT;
      case ReportTargetType.category:
        return ReportCreateRequestDtoReportTargetTypeEnum.CATEGORY;
    }
  }

  ReportCreateRequestDtoReportTypeEnum _toCreateReportTypeEnum(
    ReportType value,
  ) {
    switch (value) {
      case ReportType.spam:
        return ReportCreateRequestDtoReportTypeEnum.SPAM;
      case ReportType.hate:
        return ReportCreateRequestDtoReportTypeEnum.HATE;
      case ReportType.illegal:
        return ReportCreateRequestDtoReportTypeEnum.ILLEGAL;
      case ReportType.etc:
        return ReportCreateRequestDtoReportTypeEnum.ETC;
    }
  }

  ReportSearchRequestDtoReportTypeEnum? _toSearchReportTypeEnum(
    ReportType? value,
  ) {
    switch (value) {
      case ReportType.spam:
        return ReportSearchRequestDtoReportTypeEnum.SPAM;
      case ReportType.hate:
        return ReportSearchRequestDtoReportTypeEnum.HATE;
      case ReportType.illegal:
        return ReportSearchRequestDtoReportTypeEnum.ILLEGAL;
      case ReportType.etc:
        return ReportSearchRequestDtoReportTypeEnum.ETC;
      case null:
        return null;
    }
  }

  ReportSearchRequestDtoReportStatusEnum? _toSearchReportStatusEnum(
    ReportStatus? value,
  ) {
    switch (value) {
      case ReportStatus.pending:
        return ReportSearchRequestDtoReportStatusEnum.PADDING;
      case ReportStatus.inProgress:
        return ReportSearchRequestDtoReportStatusEnum.IN_PROGRESS;
      case ReportStatus.resolved:
        return ReportSearchRequestDtoReportStatusEnum.RESOLVED;
      case ReportStatus.rejected:
        return ReportSearchRequestDtoReportStatusEnum.REJECTED;
      case null:
        return null;
    }
  }

  ReportSearchRequestDtoReportTargetTypeEnum? _toSearchTargetTypeEnum(
    ReportTargetType? value,
  ) {
    switch (value) {
      case ReportTargetType.user:
        return ReportSearchRequestDtoReportTargetTypeEnum.USER;
      case ReportTargetType.post:
        return ReportSearchRequestDtoReportTargetTypeEnum.POST;
      case ReportTargetType.comment:
        return ReportSearchRequestDtoReportTargetTypeEnum.COMMENT;
      case ReportTargetType.category:
        return ReportSearchRequestDtoReportTargetTypeEnum.CATEGORY;
      case null:
        return null;
    }
  }

  ReportUpdateReqDtoReportStatusEnum _toUpdateReportStatusEnum(
    ReportStatus value,
  ) {
    switch (value) {
      case ReportStatus.pending:
        return ReportUpdateReqDtoReportStatusEnum.PADDING;
      case ReportStatus.inProgress:
        return ReportUpdateReqDtoReportStatusEnum.IN_PROGRESS;
      case ReportStatus.resolved:
        return ReportUpdateReqDtoReportStatusEnum.RESOLVED;
      case ReportStatus.rejected:
        return ReportUpdateReqDtoReportStatusEnum.REJECTED;
    }
  }

  SoiApiException _handleApiException(ApiException e) {
    debugPrint('🔴 API Error [${e.code}]: ${e.message}');

    switch (e.code) {
      case 400:
        return BadRequestException(
          message: e.message ?? '잘못된 신고 요청입니다.',
          originalException: e,
        );
      case 401:
        return AuthException(
          message: e.message ?? '인증이 필요합니다.',
          originalException: e,
        );
      case 403:
        return ForbiddenException(
          message: e.message ?? '신고 접근 권한이 없습니다.',
          originalException: e,
        );
      case 404:
        return NotFoundException(
          message: e.message ?? '신고 정보를 찾을 수 없습니다.',
          originalException: e,
        );
      case >= 500:
        return ServerException(
          statusCode: e.code,
          message: e.message ?? '신고 서버 오류가 발생했습니다.',
          originalException: e,
        );
      default:
        return SoiApiException(
          statusCode: e.code,
          message: e.message ?? '알 수 없는 신고 오류가 발생했습니다.',
          originalException: e,
        );
    }
  }
}
