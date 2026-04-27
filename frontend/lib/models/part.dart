enum PartState {
  good,
  needsRepair,
  missing,
  unusable;

  String toFrenchLabel() {
    switch (this) {
      case PartState.good:
        return 'Bon état';
      case PartState.needsRepair:
        return 'À réparer';
      case PartState.missing:
        return 'Manquant';
      case PartState.unusable:
        return 'Inutilisable';
    }
  }

  static PartState fromApiValue(String value) {
    switch (value) {
      case 'Good':
        return PartState.good;
      case 'NeedsRepair':
        return PartState.needsRepair;
      case 'Missing':
        return PartState.missing;
      case 'Unusable':
        return PartState.unusable;
      default:
        throw FormatException('Unknown part state: $value');
    }
  }
}

class Part {
  final String id;
  final String partKindId;
  final String partKindName;
  final int displayOrder;
  final PartState state;
  final String? comments;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Part({
    required this.id,
    required this.partKindId,
    required this.partKindName,
    required this.displayOrder,
    required this.state,
    required this.comments,
    this.createdAt,
    this.updatedAt,
  });

  factory Part.fromJson(Map<String, dynamic> json) {
    return Part(
      id: json['id'] as String,
      partKindId: json['partKindId'] as String,
      partKindName: json['partKindName'] as String,
      displayOrder: json['displayOrder'] as int,
      state: PartState.fromApiValue(json['state'] as String),
      comments: json['comments'] as String?,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}
