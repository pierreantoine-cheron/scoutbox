class Tent {
  final String id;
  final String name;
  final int size;
  final String tentShapeId;
  final String overallState;
  final String? comments;

  const Tent({
    required this.id,
    required this.name,
    required this.size,
    required this.tentShapeId,
    required this.overallState,
    required this.comments,
  });

  factory Tent.fromJson(Map<String, dynamic> json) {
    return Tent(
      id: json['id'] as String,
      name: json['name'] as String,
      size: json['size'] as int,
      tentShapeId: json['tentShapeId'] as String,
      overallState: json['overallState'] as String,
      comments: json['comments'] as String?,
    );
  }
}
