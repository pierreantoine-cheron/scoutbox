import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/tag.dart';
import 'package:client/providers/tags_provider.dart';
import 'package:client/repositories/tag_repository.dart';

void main() {
  group('TagsNotifier', () {
    test('loads tags on initialization', () async {
      final repository = _TagRepositoryStub(tags: [_tag('1', 'Bleu')]);
      final container = ProviderContainer(
        overrides: [tagRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final tags = await container.read(tagsProvider.future);

      expect(tags, hasLength(1));
      expect(tags.first.name, equals('Bleu'));
    });

    test('createTag inserts created tag alphabetically', () async {
      final repository = _TagRepositoryStub(tags: [_tag('2', 'Zoo')]);
      final container = ProviderContainer(
        overrides: [tagRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(tagsProvider.future);

      await container.read(tagsProvider.notifier).createTag(name: 'Alpha', color: '#F44336');

      final tags = container.read(tagsProvider).requireValue;
      expect(tags.map((tag) => tag.name), equals(['Alpha', 'Zoo']));
    });

    test('keeps existing data and exposes refresh failure', () async {
      final repository = _RefreshFailureTagRepository();
      final container = ProviderContainer(
        overrides: [tagRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(tagsProvider.future);

      await container.read(tagsProvider.notifier).refresh();

      expect(
        container.read(tagsProvider).requireValue.first.name,
        equals('Initial'),
      );
      expect(
        container.read(tagListRefreshIssueProvider),
        isA<TagRepositoryException>(),
      );
    });
  });
}

Tag _tag(String id, String name, {String color = '#2196F3'}) {
  return Tag(
    id: id,
    name: name,
    color: color,
    createdAt: DateTime.utc(2026, 6, 1),
    tentCount: 0,
  );
}

class _TagRepositoryStub extends TagRepository {
  final List<Tag> tags;
  int createdCount = 0;

  _TagRepositoryStub({required this.tags});

  @override
  Future<List<Tag>> getTags() async => tags;

  @override
  Future<Tag> createTag({required String name, String? color}) async {
    createdCount++;
    return _tag('created-$createdCount', name, color: color ?? '#2196F3');
  }
}

class _RefreshFailureTagRepository extends TagRepository {
  var callCount = 0;

  @override
  Future<List<Tag>> getTags() async {
    callCount++;
    if (callCount == 1) return [_tag('1', 'Initial')];
    throw const TagRepositoryException(message: 'Échec refresh');
  }
}
