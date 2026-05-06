class PartKind {
  final String id;
  final String name;
  final int displayOrder;
  final bool isStandard;

  const PartKind({
    required this.id,
    required this.name,
    required this.displayOrder,
    required this.isStandard,
  });

  factory PartKind.fromJson(Map<String, dynamic> json) {
    return PartKind(
      id: json['id'] as String,
      name: json['name'] as String,
      displayOrder: json['displayOrder'] as int,
      isStandard: json['isStandard'] as bool? ?? false,
    );
  }
}
