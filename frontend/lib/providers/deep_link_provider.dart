import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/deep_link_service.dart';

part 'deep_link_provider.g.dart';

enum DeepLinkEventKind { validInvite, incompleteInvite }

class DeepLinkEvent {
  final DeepLinkEventKind kind;
  final InviteLinkData? data;

  const DeepLinkEvent._({required this.kind, this.data});

  const DeepLinkEvent.validInvite(InviteLinkData data)
    : this._(kind: DeepLinkEventKind.validInvite, data: data);

  const DeepLinkEvent.incompleteInvite() : this._(kind: DeepLinkEventKind.incompleteInvite);
}

@riverpod
class DeepLinkNotifier extends _$DeepLinkNotifier {
  StreamSubscription<Uri>? _subscription;

  @override
  DeepLinkEvent? build() {
    _subscription = ref.read(deepLinkServiceProvider).uriLinkStream.listen(
      (uri) {
        if (!DeepLinkService.isInviteLink(uri)) {
          return;
        }
        final data = DeepLinkService.parseInviteLink(uri);
        state = data != null
            ? DeepLinkEvent.validInvite(data)
            : const DeepLinkEvent.incompleteInvite();
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
