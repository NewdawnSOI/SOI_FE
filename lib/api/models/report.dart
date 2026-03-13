import 'package:soi_api_client/api.dart';

enum ReportTargetType {
  user('USER'),
  post('POST'),
  comment('COMMENT'),
  category('CATEGORY');

  const ReportTargetType(this.value);

  final String value;
}

enum ReportType {
  spam('SPAM'),
  hate('HATE'),
  illegal('ILLEGAL'),
  etc('ETC');

  const ReportType(this.value);

  final String value;
}

enum ReportStatus {
  pending('PADDING'),
  inProgress('IN_PROGRESS'),
  resolved('RESOLVED'),
  rejected('REJECTED');

  const ReportStatus(this.value);

  final String value;
}

class Report {
  const Report({
    this.id,
    this.reporterUserId,
    this.targetId,
    this.reportTargetType,
    this.reportType,
    this.reportStatus,
    this.reportDetail,
    this.adminMemo,
    this.createTime,
    this.processTime,
  });

  final int? id;
  final int? reporterUserId;
  final int? targetId;
  final ReportTargetType? reportTargetType;
  final ReportType? reportType;
  final ReportStatus? reportStatus;
  final String? reportDetail;
  final String? adminMemo;
  final DateTime? createTime;
  final DateTime? processTime;

  factory Report.fromDto(ReportResponseDto dto) {
    return Report(
      id: dto.id,
      reporterUserId: dto.reporterUserId,
      targetId: dto.targetId,
      reportTargetType: _targetTypeFromDto(dto.reportTargetType),
      reportType: _reportTypeFromDto(dto.reportType),
      reportStatus: _reportStatusFromDto(dto.reportStatus),
      reportDetail: dto.reportDetail,
      adminMemo: dto.adminMemo,
      createTime: dto.createTime,
      processTime: dto.processTime,
    );
  }

  static ReportTargetType? _targetTypeFromDto(
    ReportResponseDtoReportTargetTypeEnum? value,
  ) {
    switch (value) {
      case ReportResponseDtoReportTargetTypeEnum.USER:
        return ReportTargetType.user;
      case ReportResponseDtoReportTargetTypeEnum.POST:
        return ReportTargetType.post;
      case ReportResponseDtoReportTargetTypeEnum.COMMENT:
        return ReportTargetType.comment;
      case ReportResponseDtoReportTargetTypeEnum.CATEGORY:
        return ReportTargetType.category;
      default:
        return null;
    }
  }

  static ReportType? _reportTypeFromDto(
    ReportResponseDtoReportTypeEnum? value,
  ) {
    switch (value) {
      case ReportResponseDtoReportTypeEnum.SPAM:
        return ReportType.spam;
      case ReportResponseDtoReportTypeEnum.HATE:
        return ReportType.hate;
      case ReportResponseDtoReportTypeEnum.ILLEGAL:
        return ReportType.illegal;
      case ReportResponseDtoReportTypeEnum.ETC:
        return ReportType.etc;
      default:
        return null;
    }
  }

  static ReportStatus? _reportStatusFromDto(
    ReportResponseDtoReportStatusEnum? value,
  ) {
    switch (value) {
      case ReportResponseDtoReportStatusEnum.PADDING:
        return ReportStatus.pending;
      case ReportResponseDtoReportStatusEnum.IN_PROGRESS:
        return ReportStatus.inProgress;
      case ReportResponseDtoReportStatusEnum.RESOLVED:
        return ReportStatus.resolved;
      case ReportResponseDtoReportStatusEnum.REJECTED:
        return ReportStatus.rejected;
      default:
        return null;
    }
  }
}
