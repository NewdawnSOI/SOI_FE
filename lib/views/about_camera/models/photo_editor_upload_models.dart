import 'dart:io';

/// 텍스트 전용 게시물 생성 시 사용하는 고정 기본값
/// [TextOnlyPostCreateDefaults]는 텍스트 전용 게시물 생성 시 사용되는 고정된 기본값을 정의하는 클래스입니다.
/// 이 클래스는 텍스트 전용 게시물 생성에 필요한 기본값을 제공하여 업로드 프로세스에서 일관된 데이터를 사용할 수 있도록 합니다.
/// 텍스트 전용 게시물 생성 시에는 미디어 파일과 관련된 값들이 필요하지 않으므로, 해당 값들은 빈 문자열이나 null로 설정되어 있습니다.
///
/// fields:
/// - [postFileKey]: 텍스트 전용 게시물의 미디어 파일 키 목록입니다. 텍스트 전용 게시물에는 미디어 파일이 없으므로 빈 문자열이 포함된 리스트로 설정되어 있습니다.
/// - [audioFileKey]: 텍스트 전용 게시물의 오디오 파일 키 목록입니다. 텍스트 전용 게시물에는 오디오 파일이 없으므로 빈 문자열이 포함된 리스트로 설정되어 있습니다.
/// - [waveformData]: 텍스트 전용 게시물의 웨이브폼 데이터입니다. 텍스트 전용 게시물에는 오디오가 없으므로 빈 문자열로 설정되어 있습니다.
/// - [duration]: 텍스트 전용 게시물의 오디오 길이(초)입니다. 텍스트 전용 게시물에는 오디오가 없으므로 0으로 설정되어 있습니다.
/// - [savedAspectRatio]: 텍스트 전용 게시물의 저장된 가로세로 비율입니다. 텍스트 전용 게시물에는 미디어가 없으므로 0으로 설정되어 있습니다.
/// - [isFromGallery]: 텍스트 전용 게시물이 갤러리에서 생성된 것인지 여부입니다. 텍스트 전용 게시물은 갤러리에서 생성된 것으로 간주되어 true로 설정되어 있습니다.
class TextOnlyPostCreateDefaults {
  TextOnlyPostCreateDefaults._();

  static const List<String> postFileKey = [''];
  static const List<String> audioFileKey = [''];
  static const String waveformData = '';
  static const int duration = 0;
  static const double savedAspectRatio = 0;
  static const bool isFromGallery = true;
}

/// 서버 업로드 실행 직전 실제 payload 데이터
/// [UploadPayload]은 서버 업로드 실행 직전에 사용되는 데이터 모델로, 업로드에 필요한 모든 정보를 포함합니다.
/// 이 모델은 업로드 프로세스 전반에 걸쳐 일관된 데이터를 제공하기 위해 사용됩니다.
/// 업로드 과정에서 데이터가 변경되더라도 초기 상태를 유지하여 업로드 실행 시점에 필요한 모든 정보를 포함하는 모델입니다.
///
/// fields:
/// - [userId]: 업로드를 수행하는 사용자의 고유 식별자입니다.
/// - [nickName]: 업로드를 수행하는 사용자의 닉네임입니다.
/// - [mediaFile]: 업로드할 미디어 파일입니다.
/// - [mediaPath]: 업로드할 미디어 파일의 경로입니다.
/// - [isVideo]: 업로드할 미디어가 비디오인지 여부를 나타냅니다.
/// - [audioFile]: 사용자가 녹음한 오디오 파일입니다. 오디오가 없는 경우 null입니다.
/// - [audioPath]: 사용자가 녹음한 오디오 파일의 경로입니다. 오디오가 없는 경우 null입니다.
/// - [caption]: 게시물에 추가할 캡션 텍스트입니다. 캡션이 없는 경우 null입니다.
/// - [waveformData]: 녹음된 오디오의 웨이브폼 데이터입니다. 오디오가 없는 경우 null입니다.
/// - [audioDurationSeconds]: 녹음된 오디오의 길이를 초 단위로 나타낸 값입니다. 오디오가 없는 경우 null입니다.
/// - [usageCount]: 사용자가 업로드한 게시물의 총 개수입니다. 이 값은 서버에서 업로드된 게시물의 고유한 식별자 생성을 위해 사용될 수 있습니다.
/// - [aspectRatio]: 업로드할 미디어의 가로세로 비율입니다. 이 값은 클라이언트에서 미디어 파일을 분석하여 계산된 값입니다. 비디오의 경우 null이 될 수 있습니다.
/// - [isFromGallery]: 미디어가 갤러리에서 선택된 것인지 여부를 나타냅니다. 카메라로 촬영한 미디어는 false로 설정됩니다.
class UploadPayload {
  final int userId;
  final String nickName;
  final File mediaFile;
  final String mediaPath;
  final bool isVideo;
  final File? audioFile;
  final String? audioPath;
  final String? caption;
  final List<double>? waveformData;
  final int? audioDurationSeconds;
  final int usageCount;
  final double? aspectRatio;
  final bool isFromGallery;

  const UploadPayload({
    required this.userId,
    required this.nickName,
    required this.mediaFile,
    required this.mediaPath,
    required this.isVideo,
    required this.usageCount,
    required this.isFromGallery,
    this.audioFile,
    this.audioPath,
    this.caption,
    this.waveformData,
    this.audioDurationSeconds,
    this.aspectRatio,
  });
}

/// 화면 전환 이전에 캡처해 두는 업로드 스냅샷
/// [UploadSnapshot]은 업로드 프로세스 시작 전에 캡처되는 데이터 스냅샷을 나타내는 모델입니다.
/// 이 모델은 업로드에 필요한 모든 정보를 포함하며, 업로드 과정에서 데이터가 변경되더라도 초기 상태를 유지합니다.
/// 이를 통해 업로드 프로세스 전반에 걸쳐 일관된 데이터를 사용할 수 있습니다.
///
/// fields:
/// - [userId]: 업로드를 수행하는 사용자의 고유 식별자입니다.
/// - [nickName]: 업로드를 수행하는 사용자의 닉네임입니다.
/// - [filePath]: 업로드할 미디어 파일의 경로입니다.
/// - [isVideo]: 업로드할 미디어가 비디오인지 여부를 나타냅니다.
/// - [isFromGallery]: 미디어가 갤러리에서 선택된 것인지 여부를 나타냅니다.
/// - [captionText]: 게시물에 추가할 캡션 텍스트입니다.
/// - [recordedAudioPath]: 사용자가 녹음한 오디오 파일의 경로입니다. 오디오가 없는 경우 null입니다.
/// - [recordedWaveformData]: 녹음된 오디오의 웨이브폼 데이터입니다. 오디오가 없는 경우 null입니다.
/// - [recordedAudioDurationSeconds]: 녹음된 오디오의 길이를 초 단위로 나타낸 값입니다. 오디오가 없는 경우 null입니다.
/// - [categoryIds]: 게시물에 연결된 카테고리 ID 목록입니다.
/// - [compressionTask]: 미디어 파일 압축 작업을 나타내는 Future입니다. 압축이 완료되면 압축된 파일이 반환됩니다. 압축이 필요 없는 경우 null입니다.
/// - [compressedFile]: 이미 압축된 미디어 파일입니다. 압축이 필요 없는 경우 null입니다.
/// - [lastCompressedPath]: 마지막으로 압축된 파일의 경로입니다. 압축이 필요 없는 경우 null입니다.
class UploadSnapshot {
  final int userId;
  final String nickName;
  final String filePath;
  final bool isVideo;
  final bool isFromGallery;
  final String captionText;
  final String? recordedAudioPath;
  final List<double>? recordedWaveformData;
  final int? recordedAudioDurationSeconds;
  final List<int> categoryIds;
  final Future<File>? compressionTask;
  final File? compressedFile;
  final String? lastCompressedPath;

  const UploadSnapshot({
    required this.userId,
    required this.nickName,
    required this.filePath,
    required this.isVideo,
    required this.isFromGallery,
    required this.captionText,
    required this.categoryIds,
    required this.compressionTask,
    required this.compressedFile,
    required this.lastCompressedPath,
    this.recordedAudioPath,
    this.recordedWaveformData,
    this.recordedAudioDurationSeconds,
  });
}

/// 업로드 후 반환된 미디어 키 집합
class MediaUploadResult {
  final List<String> mediaKeys;
  final List<String> audioKeys;

  const MediaUploadResult({required this.mediaKeys, required this.audioKeys});
}
