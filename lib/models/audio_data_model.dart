import 'package:cloud_firestore/cloud_firestore.dart';

/// 오디오 데이터 모델 (순수 데이터 클래스)
class AudioDataModel {
  final String id;
  final String categoryId;
  final String userId;
  final String fileName;
  final String originalPath;
  final String? convertedPath;
  final String? firebaseUrl;
  final int durationInSeconds;
  final double fileSizeInMB;
  final AudioFormat format;
  final AudioStatus status;
  final DateTime createdAt;
  final DateTime? uploadedAt;
  final String? description;

  AudioDataModel({
    required this.id,
    required this.categoryId,
    required this.userId,
    required this.fileName,
    required this.originalPath,
    this.convertedPath,
    this.firebaseUrl,
    required this.durationInSeconds,
    required this.fileSizeInMB,
    required this.format,
    required this.status,
    required this.createdAt,
    this.uploadedAt,
    this.description,
  });

  // Firestore에서 데이터를 가져올 때 사용
  factory AudioDataModel.fromFirestore(Map<String, dynamic> data, String id) {
    return AudioDataModel(
      id: id,
      categoryId: data['categoryId'] ?? '',
      userId: data['userId'] ?? '',
      fileName: data['fileName'] ?? '',
      originalPath: data['originalPath'] ?? '',
      convertedPath: data['convertedPath'],
      firebaseUrl: data['firebaseUrl'],
      durationInSeconds: data['durationInSeconds'] ?? 0,
      fileSizeInMB: (data['fileSizeInMB'] ?? 0.0).toDouble(),
      format: AudioFormat.values.firstWhere(
        (e) => e.name == data['format'],
        orElse: () => AudioFormat.aac,
      ),
      status: AudioStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => AudioStatus.recorded,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate(),
      description: data['description'],
    );
  }

  // Firestore에 저장할 때 사용
  Map<String, dynamic> toFirestore() {
    return {
      'categoryId': categoryId,
      'userId': userId,
      'fileName': fileName,
      'originalPath': originalPath,
      'convertedPath': convertedPath,
      'firebaseUrl': firebaseUrl,
      'durationInSeconds': durationInSeconds,
      'fileSizeInMB': fileSizeInMB,
      'format': format.name,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'uploadedAt': uploadedAt != null ? Timestamp.fromDate(uploadedAt!) : null,
      'description': description,
    };
  }

  // 복사본 생성 (일부 필드 업데이트용)
  AudioDataModel copyWith({
    String? id,
    String? categoryId,
    String? userId,
    String? fileName,
    String? originalPath,
    String? convertedPath,
    String? firebaseUrl,
    int? durationInSeconds,
    double? fileSizeInMB,
    AudioFormat? format,
    AudioStatus? status,
    DateTime? createdAt,
    DateTime? uploadedAt,
    String? description,
  }) {
    return AudioDataModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      userId: userId ?? this.userId,
      fileName: fileName ?? this.fileName,
      originalPath: originalPath ?? this.originalPath,
      convertedPath: convertedPath ?? this.convertedPath,
      firebaseUrl: firebaseUrl ?? this.firebaseUrl,
      durationInSeconds: durationInSeconds ?? this.durationInSeconds,
      fileSizeInMB: fileSizeInMB ?? this.fileSizeInMB,
      format: format ?? this.format,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      description: description ?? this.description,
    );
  }

  @override
  String toString() {
    return 'AudioDataModel(id: $id, fileName: $fileName, status: $status, duration: ${durationInSeconds}s)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioDataModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  /// 파일 크기를 읽기 쉬운 형태로 반환
  String get readableFileSize {
    if (fileSizeInMB < 1) {
      return '${(fileSizeInMB * 1024).toStringAsFixed(1)} KB';
    }
    return '${fileSizeInMB.toStringAsFixed(1)} MB';
  }

  /// 녹음 시간을 MM:SS 형태로 반환
  String get formattedDuration {
    final minutes = durationInSeconds ~/ 60;
    final seconds = durationInSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 업로드 가능한 상태인지 확인
  bool get canUpload =>
      status == AudioStatus.converted || status == AudioStatus.recorded;

  /// 재생 가능한 상태인지 확인
  bool get canPlay => originalPath.isNotEmpty || firebaseUrl != null;
}

/// 오디오 파일 포맷
enum AudioFormat { aac, mp3, wav, m4a }

/// 오디오 상태
enum AudioStatus {
  recording, // 녹음 중
  recorded, // 녹음 완료
  converting, // 변환 중
  converted, // 변환 완료
  uploading, // 업로드 중
  uploaded, // 업로드 완료
  failed, // 실패
}
