import 'package:app_links/app_links.dart';

class InviteLinkData {
  final String serverUrl;
  final String inviteCode;

  const InviteLinkData({required this.serverUrl, required this.inviteCode});
}

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  static bool _everConsumed = false;

  Stream<Uri> get uriLinkStream => _appLinks.uriLinkStream;

  Future<Uri?> getInitialLink() async {
    if (_everConsumed) return null;
    final link = await _appLinks.getInitialLink();
    if (link != null) {
      _everConsumed = true;
    }
    return link;
  }

  static void consumeInitialLink() {
    _everConsumed = true;
  }

  static InviteLinkData? parseInviteLink(Uri uri) {
    if (uri.scheme != 'scoutbox' || uri.host != 'register') {
      return null;
    }
    final serverUrl = uri.queryParameters['server'];
    final inviteCode = uri.queryParameters['invite'];
    if (serverUrl == null || inviteCode == null || serverUrl.isEmpty || inviteCode.isEmpty) {
      return null;
    }
    return InviteLinkData(
      serverUrl: Uri.decodeComponent(serverUrl),
      inviteCode: Uri.decodeComponent(inviteCode),
    );
  }
}
