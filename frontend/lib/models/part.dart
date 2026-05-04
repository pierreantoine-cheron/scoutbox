import '../utils/date_time_parser.dart';

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

  String toApiValue() {
    switch (this) {
      case PartState.good:
        return 'Good';
      case PartState.needsRepair:
        return 'NeedsRepair';
      case PartState.missing:
        return 'Missing';
      case PartState.unusable:
        return 'Unusable';
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
      createdAt: DateTimeParser.parseNullable(json['createdAt']),
      updatedAt: DateTimeParser.parseNullable(json['updatedAt']),
    );
  }
}
