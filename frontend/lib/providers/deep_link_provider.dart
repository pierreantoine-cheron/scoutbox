import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/deep_link_service.dart';

part 'deep_link_provider.g.dart';

@riverpod
class DeepLinkNotifier extends _$DeepLinkNotifier {
  StreamSubscription<Uri>? _subscription;

  @override
  InviteLinkData? build() {
    _subscription = ref.read(deepLinkServiceProvider).uriLinkStream.listen(
      (uri) {
        final data = DeepLinkService.parseInviteLink(uri);
        if (data != null) {
          state = data;
        }
      },
    );
    ref.onDispose(() {
      _subscription?.cancel();
    });
    return null;
  }

  void clear() {
    state = null;
  }
}

@riverpod
DeepLinkService deepLinkService(Ref ref) {
  return DeepLinkService();
}
