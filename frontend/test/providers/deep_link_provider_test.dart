import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:client/services/deep_link_service.dart';
import 'package:client/providers/deep_link_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _FakeDeepLinkService extends DeepLinkService {
  final _controller = StreamController<Uri>();

  @override
  Stream<Uri> get uriLinkStream => _controller.stream;

  @override
  Future<Uri?> getInitialLink() async => null;

  void emit(Uri uri) {
    _controller.add(uri);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

void main() {
  group('DeepLinkNotifier', () {
    late _FakeDeepLinkService fakeService;
    late ProviderContainer container;
    late ProviderSubscription<DeepLinkEvent?> subscription;

    setUp(() {
      fakeService = _FakeDeepLinkService();
      container = ProviderContainer(
        overrides: [
          deepLinkServiceProvider.overrideWithValue(fakeService),
        ],
      );
      subscription = container.listen(deepLinkProvider, (_, _) {});
    });

    tearDown(() async {
      subscription.close();
      container.dispose();
      await fakeService.dispose();
    });

    test('starts with null state', () {
      expect(container.read(deepLinkProvider), isNull);
    });

    test('updates state when a valid invite link is received', () async {
      fakeService.emit(
        Uri.parse('scoutbox://register?server=https://test.fr&invite=INVITE-1'),
      );

      await Future<void>.delayed(Duration.zero);

      final event = container.read(deepLinkProvider);
      expect(event, isNotNull);
      expect(event!.kind, DeepLinkEventKind.validInvite);
      expect(event.data!.serverUrl, 'https://test.fr');
      expect(event.data!.inviteCode, 'INVITE-1');
    });

    test('emits incomplete event for invite links with missing params', () async {
      fakeService.emit(Uri.parse('scoutbox://register?server=https://test.fr'));

      await Future<void>.delayed(Duration.zero);

      final event = container.read(deepLinkProvider);
      expect(event, isNotNull);
      expect(event!.kind, DeepLinkEventKind.incompleteInvite);
      expect(event.data, isNull);
    });

    test('ignores links outside the invite contract', () async {
      fakeService.emit(Uri.parse('scoutbox://settings?server=https://test.fr'));

      await Future<void>.delayed(Duration.zero);

      expect(container.read(deepLinkProvider), isNull);
    });

    test('clear resets state to null', () async {
      fakeService.emit(
        Uri.parse('scoutbox://register?server=https://test.fr&invite=INVITE-1'),
      );
      await Future<void>.delayed(Duration.zero);

      container.read(deepLinkProvider.notifier).clear();

      expect(container.read(deepLinkProvider), isNull);
    });
  });
}
