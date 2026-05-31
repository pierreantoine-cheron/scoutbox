class PartKind {
  final String id;
  final String name;
  final int displayOrder;

  const PartKind({
    required this.id,
    required this.name,
    required this.displayOrder,
  });

  factory PartKind.fromJson(Map<String, dynamic> json) {
    return PartKind(
      id: json['id'] as String,
      name: json['name'] as String,
      displayOrder: json['displayOrder'] as int,
    );
  }
}
