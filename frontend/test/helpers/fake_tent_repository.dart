import 'package:client/models/models.dart';
import 'package:client/repositories/tent_repository.dart';

typedef GetTentsHandler = Future<List<Tent>> Function();
typedef GetTentShapesHandler = Future<List<TentShape>> Function();
typedef GetTentHandler = Future<Tent> Function(String id);
typedef UpdateTentHandler = Future<Tent> Function({
  required String id,
  required String name,
  required int size,
  required TentOverallState overallState,
  String? comments,
});
typedef CreateTentHandler = Future<Tent> Function({
  required String name,
  required int size,
  required String tentShapeId,
  required TentOverallState overallState,
  String? comments,
});
typedef ArchiveTentHandler = Future<Tent> Function(String id);
typedef AddPartsToTentHandler = Future<List<Part>> Function({
  required String tentId,
  required List<String> partKindIds,
});
typedef RemovePartHandler = Future<void> Function({required String partId});
typedef GetPartKindsHandler = Future<List<PartKind>> Function();
typedef GetTentHistoryHandler = Future<List<TentHistoryItem>> Function({
  required String tentId,
  String? category,
  int limit,
});
typedef UpdatePartStateHandler = Future<Part> Function({
  required String id,
  required PartState state,
  required String? comments,
});

class FakeTentRepository extends TentRepository {
  GetTentsHandler? getTentsHandler;
  GetTentShapesHandler? getTentShapesHandler;
  GetTentHandler? getTentHandler;
  UpdateTentHandler? updateTentHandler;
  CreateTentHandler? createTentHandler;
  ArchiveTentHandler? archiveTentHandler;
  AddPartsToTentHandler? addPartsToTentHandler;
  RemovePartHandler? removePartHandler;
  GetPartKindsHandler? getPartKindsHandler;
  GetTentHistoryHandler? getTentHistoryHandler;
  UpdatePartStateHandler? updatePartStateHandler;

  @override
  Future<List<Tent>> getTents() {
    final handler = getTentsHandler;
    if (handler == null) throw UnimplementedError('getTents');
    return handler();
  }

  @override
  Future<List<TentShape>> getTentShapes() {
    final handler = getTentShapesHandler;
    if (handler == null) throw UnimplementedError('getTentShapes');
    return handler();
  }

  @override
  Future<Tent> getTent(String id) {
    final handler = getTentHandler;
    if (handler == null) throw UnimplementedError('getTent');
    return handler(id);
  }

  @override
  Future<Tent> updateTent({
    required String id,
    required String name,
    required int size,
    required TentOverallState overallState,
    String? comments,
  }) {
    final handler = updateTentHandler;
    if (handler == null) throw UnimplementedError('updateTent');
    return handler(
      id: id,
      name: name,
      size: size,
      overallState: overallState,
      comments: comments,
    );
  }

  @override
  Future<Tent> createTent({
    required String name,
    required int size,
    required String tentShapeId,
    required TentOverallState overallState,
    String? comments,
  }) {
    final handler = createTentHandler;
    if (handler == null) throw UnimplementedError('createTent');
    return handler(
      name: name,
      size: size,
      tentShapeId: tentShapeId,
      overallState: overallState,
      comments: comments,
    );
  }

  @override
  Future<Tent> archiveTent(String id) {
    final handler = archiveTentHandler;
    if (handler == null) throw UnimplementedError('archiveTent');
    return handler(id);
  }

  @override
  Future<List<Part>> addPartsToTent({
    required String tentId,
    required List<String> partKindIds,
  }) {
    final handler = addPartsToTentHandler;
    if (handler == null) throw UnimplementedError('addPartsToTent');
    return handler(tentId: tentId, partKindIds: partKindIds);
  }

  @override
  Future<void> removePart({required String partId}) {
    final handler = removePartHandler;
    if (handler == null) throw UnimplementedError('removePart');
    return handler(partId: partId);
  }

  @override
  Future<List<PartKind>> getPartKinds() {
    final handler = getPartKindsHandler;
    if (handler == null) throw UnimplementedError('getPartKinds');
    return handler();
  }

  @override
  Future<List<TentHistoryItem>> getTentHistory({
    required String tentId,
    String? category,
    int limit = 50,
  }) {
    final handler = getTentHistoryHandler;
    if (handler == null) throw UnimplementedError('getTentHistory');
    return handler(tentId: tentId, category: category, limit: limit);
  }

  @override
  Future<Part> updatePartState({
    required String id,
    required PartState state,
    required String? comments,
  }) {
    final handler = updatePartStateHandler;
    if (handler == null) throw UnimplementedError('updatePartState');
    return handler(id: id, state: state, comments: comments);
  }
}
