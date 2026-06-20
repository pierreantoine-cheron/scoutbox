class PartKind {
  final String id;
  final String name;
  final int displayOrder;
  final int tentCount;

  const PartKind({
    required this.id,
    required this.name,
    required this.displayOrder,
    required this.tentCount,
  });

  factory PartKind.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String) {
      throw const FormatException('PartKind id must be a string');
    }
    final name = json['name'];
    if (name is! String) {
      throw const FormatException('PartKind name must be a string');
    }
    final displayOrder = json['displayOrder'];
    if (displayOrder is! int) {
      throw const FormatException('PartKind displayOrder must be an integer');
    }
    final tentCount = json['tentCount'];
    if (tentCount is! int) {
      throw const FormatException('PartKind tentCount must be an integer');
    }
    return PartKind(
      id: id,
      name: name,
      displayOrder: displayOrder,
      tentCount: tentCount,
    );
  }
}
