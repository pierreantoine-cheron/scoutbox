import 'package:intl/intl.dart';

import '../utils/date_time_parser.dart';
import 'part.dart';

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
  final String tentModelId;
  final String? tentModelName;
  final TentOverallState overallState;
  final bool isArchived;
  final String? comments;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<Part> parts;

  const Tent({
    required this.id,
    required this.name,
    required this.size,
    required this.tentModelId,
    this.tentModelName,
    required this.overallState,
    this.isArchived = false,
    required this.comments,
    this.createdAt,
    this.updatedAt,
    this.parts = const [],
  });

  factory Tent.fromJson(Map<String, dynamic> json) {
    return Tent(
      id: json['id'] as String,
      name: json['name'] as String,
      size: json['size'] as int,
      tentModelId: json['tentModelId'] as String,
      tentModelName: json['tentModelName'] as String?,
      overallState: TentOverallState.fromApiValue(
        json['overallState'] as String,
      ),
      isArchived: json['isArchived'] as bool? ?? false,
      comments: json['comments'] as String?,
      createdAt: DateTimeParser.parseNullable(json['createdAt']),
      updatedAt: DateTimeParser.parseNullable(json['updatedAt']),
      parts: _parseParts(json['parts']),
    );
  }

  String toFrenchUpdatedAtLabel(DateFormat formatter) {
    final value = updatedAt;
    if (value == null) {
      return '-';
    }

    return formatter.format(value.toLocal());
  }

  static List<Part> _parseParts(Object? value) {
    if (value == null) {
      return const [];
    }

    if (value is List<dynamic>) {
      return value
          .map((part) => Part.fromJson(part as Map<String, dynamic>))
          .toList();
    }

    throw const FormatException('Tent parts field is not a list');
  }
}
