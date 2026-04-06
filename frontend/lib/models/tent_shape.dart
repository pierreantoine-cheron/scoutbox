class TentShape {
  final String id;
  final String name;
  final int displayOrder;
  final bool isActive;

  const TentShape({
    required this.id,
    required this.name,
    required this.displayOrder,
    required this.isActive,
  });

  factory TentShape.fromJson(Map<String, dynamic> json) {
    return TentShape(
      id: json['id'] as String,
      name: json['name'] as String,
      displayOrder: json['displayOrder'] as int,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
