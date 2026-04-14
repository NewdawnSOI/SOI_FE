import '../../../../api/models/comment.dart';

class PhotoTagDomainUtils {
  const PhotoTagDomainUtils._();

  static bool canExpandMediaComment(Comment comment) {
    if (comment.type != CommentType.photo) {
      return false;
    }

    final fileUrl = (comment.fileUrl ?? '').trim();
    if (fileUrl.isNotEmpty) {
      return true;
    }

    final fileKey = (comment.fileKey ?? '').trim();
    return fileKey.isNotEmpty;
  }
}
