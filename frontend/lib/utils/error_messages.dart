import '../repositories/part_kind_repository.dart';
import '../repositories/tag_repository.dart';
import '../repositories/tent_repository.dart';
import '../services/error_localizer.dart';

String toUserFacingError(Object error, String fallback) {
  if (error is TentRepositoryException) {
    return ErrorLocalizer.localize(error.code, fallback: error.message);
  }
  if (error is TagRepositoryException) {
    return ErrorLocalizer.localize(error.code, fallback: error.message);
  }
  if (error is PartKindRepositoryException) {
    return ErrorLocalizer.localize(error.code, fallback: error.message);
  }
  return fallback;
}

String? toRefreshWarning(Object? issue, String fallbackDetail) {
  if (issue == null) return null;
  final detail = toUserFacingError(issue, fallbackDetail);
  return 'Les données affichées peuvent être anciennes. $detail';
}
