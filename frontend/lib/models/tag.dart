import '../utils/date_time_parser.dart';

class Tag {
  final String id;
  final String name;
  final String color;
  final DateTime createdAt;
  final int tentCount;

  const Tag({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
    required this.tentCount,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final color = json['color'];
    final tentCount = json['tentCount'];

    if (id is! String || id.isEmpty) {
      throw const FormatException('Tag id is required');
    }
    if (name is! String || name.isEmpty) {
      throw const FormatException('Tag name is required');
    }
    if (color is! String || color.isEmpty) {
      throw const FormatException('Tag color is required');
    }
    if (tentCount is! int) {
      throw const FormatException('Tag tentCount must be an integer');
    }

    return Tag(
      id: id,
      name: name,
      color: color,
      createdAt: DateTimeParser.parseRequired(
        json['createdAt'],
        fieldName: 'createdAt',
      ),
      tentCount: tentCount,
    );
  }
}
