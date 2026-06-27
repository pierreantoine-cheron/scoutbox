import 'package:app_links/app_links.dart';

class InviteLinkData {
  final String serverUrl;
  final String inviteCode;

  const InviteLinkData({required this.serverUrl, required this.inviteCode});
}

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  static bool _everConsumed = false;
  static final Set<String> _consumedLinks = <String>{};
  static final Set<String> _consumedInviteData = <String>{};

  Stream<Uri> get uriLinkStream => _appLinks.uriLinkStream;

  Future<Uri?> getInitialLink() async {
    if (_everConsumed) return null;
    final link = await _appLinks.getInitialLink();
    if (link == null || _everConsumed || isConsumed(link)) {
      return null;
    }
    consumeLink(link);
    return link;
  }

  static void consumeInitialLink() {
    _everConsumed = true;
  }

  static bool isConsumed(Uri uri) {
    final data = parseInviteLink(uri);
    return _consumedLinks.contains(uri.toString()) ||
        (data != null && _consumedInviteData.contains(_inviteDataKey(data)));
  }

  static void consumeLink(Uri uri) {
    _everConsumed = true;
    _consumedLinks.add(uri.toString());
    final data = parseInviteLink(uri);
    if (data != null) {
      _consumedInviteData.add(_inviteDataKey(data));
    }
  }

  static String _inviteDataKey(InviteLinkData data) {
    return '${Uri.encodeComponent(data.serverUrl)}|${Uri.encodeComponent(data.inviteCode)}';
  }

  static bool isInviteLink(Uri uri) {
    return uri.scheme == 'scoutbox' && uri.host == 'register';
  }

  static InviteLinkData? parseInviteLink(Uri uri) {
    if (!isInviteLink(uri)) {
      return null;
    }
    final serverUrl = uri.queryParameters['server'];
    final inviteCode = uri.queryParameters['invite'];
    if (serverUrl == null || inviteCode == null || serverUrl.isEmpty || inviteCode.isEmpty) {
      return null;
    }
    return InviteLinkData(
      serverUrl: serverUrl,
      inviteCode: inviteCode,
    );
  }
}
