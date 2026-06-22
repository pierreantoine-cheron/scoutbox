class TentModel {
  final String id;
  final String name;
  final int displayOrder;
  final bool isActive;
  final int tentCount;
  final int componentCount;
  final List<String> componentIds;

  const TentModel({
    required this.id,
    required this.name,
    required this.displayOrder,
    required this.isActive,
    this.tentCount = 0,
    this.componentCount = 0,
    this.componentIds = const [],
  });

  factory TentModel.fromJson(Map<String, dynamic> json) {
    return TentModel(
      id: json['id'] as String,
      name: json['name'] as String,
      displayOrder: json['displayOrder'] as int,
      isActive: json['isActive'] as bool? ?? true,
      tentCount: json['tentCount'] as int? ?? 0,
      componentCount: json['componentCount'] as int? ?? 0,
      componentIds: (json['componentIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}
