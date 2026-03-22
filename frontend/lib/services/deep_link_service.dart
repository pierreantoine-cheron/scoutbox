import 'package:app_links/app_links.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'deep_link_service.g.dart';

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();

  Stream<Uri> get deepLinkStream => _appLinks.uriLinkStream;

  Future<Uri?> getInitialLink() async {
    return await _appLinks.getInitialLink();
  }

  static InviteLinkData? parseInviteLink(Uri uri) {
    if (uri.scheme != 'scoutbox') {
      return null;
    }

    // Support both formats:
    // - scoutbox://register?server=... (host='register')
    // - scoutbox:///register?server=... (path='/register')
    final isRegisterHost = uri.host == 'register';
    final isRegisterPath = uri.path == '/register' || uri.path == 'register';
    
    if (!isRegisterHost && !isRegisterPath) {
      return null;
    }

    final serverUrl = uri.queryParameters['server'];
    final inviteCode = uri.queryParameters['invite'];

    if (serverUrl == null || inviteCode == null) {
      return null;
    }

    return InviteLinkData(serverUrl: serverUrl, inviteCode: inviteCode);
  }
}

class InviteLinkData {
  final String serverUrl;
  final String inviteCode;

  InviteLinkData({required this.serverUrl, required this.inviteCode});
}

@riverpod
DeepLinkService deepLinkService(Ref ref) {
  return DeepLinkService();
}
