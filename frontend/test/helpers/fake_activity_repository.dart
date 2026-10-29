import 'package:client/models/activity_item.dart';
import 'package:client/repositories/activity_repository.dart';

typedef GetActivityHandler =
    Future<ActivityPage> Function(
      String category,
      String window,
      String? cursor,
      int limit,
    );

class FakeActivityRepository extends ActivityRepository {
  GetActivityHandler? handler;

  @override
  Future<ActivityPage> getActivity({
    String category = 'all',
    String window = '30',
    String? cursor,
    int limit = 50,
  }) {
    final current = handler;
    if (current == null) throw UnimplementedError('getActivity');
    return current(category, window, cursor, limit);
  }
}
