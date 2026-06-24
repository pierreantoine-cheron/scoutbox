class InviteResponse {
  final String id;
  final String code;
  final DateTime expiresAt;
  final bool isUsed;

  const InviteResponse({
    required this.id,
    required this.code,
    required this.expiresAt,
    required this.isUsed,
  });
}
