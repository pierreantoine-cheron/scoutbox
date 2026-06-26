import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:client/services/deep_link_service.dart';
import 'package:client/providers/deep_link_provider.dart';

void main() {
  group('DeepLinkNotifier', () {
    testWidgets('deepLinkServiceProvider returns a DeepLinkService', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: _TestWidget())),
      );

      // The provider is accessible within the widget tree
      expect(find.text('service loaded'), findsOneWidget);
    });
  });
}

class _TestWidget extends ConsumerWidget {
  const _TestWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(deepLinkServiceProvider);
    return Text(service is DeepLinkService ? 'service loaded' : 'failed');
  }
}
