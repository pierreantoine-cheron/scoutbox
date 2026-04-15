enum TentOverallState {
  good,
  needsRepair,
  unusable;

  String toApiValue() {
    switch (this) {
      case TentOverallState.good:
        return 'Good';
      case TentOverallState.needsRepair:
        return 'NeedsRepair';
      case TentOverallState.unusable:
        return 'Unusable';
    }
  }

  String toFrenchLabel() {
    switch (this) {
      case TentOverallState.good:
        return 'Bon état';
      case TentOverallState.needsRepair:
        return 'À réparer';
      case TentOverallState.unusable:
        return 'Inutilisable';
    }
  }

  static TentOverallState fromApiValue(String value) {
    switch (value) {
      case 'Good':
        return TentOverallState.good;
      case 'NeedsRepair':
        return TentOverallState.needsRepair;
      case 'Unusable':
        return TentOverallState.unusable;
      default:
        throw FormatException('Unknown tent overall state: $value');
    }
  }
}

class Tent {
  final String id;
  final String name;
  final int size;
  final String tentShapeId;
  final String? tentShapeName;
  final TentOverallState overallState;
  final String? comments;

  const Tent({
    required this.id,
    required this.name,
    required this.size,
    required this.tentShapeId,
    this.tentShapeName,
    required this.overallState,
    required this.comments,
  });

  factory Tent.fromJson(Map<String, dynamic> json) {
    return Tent(
      id: json['id'] as String,
      name: json['name'] as String,
      size: json['size'] as int,
      tentShapeId: json['tentShapeId'] as String,
      tentShapeName: json['tentShapeName'] as String?,
      overallState: TentOverallState.fromApiValue(
        json['overallState'] as String,
      ),
      comments: json['comments'] as String?,
    );
  }
}
