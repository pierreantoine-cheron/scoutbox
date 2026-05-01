class DateTimeParser {
  DateTimeParser._();

  static DateTime? parseNullable(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value);
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  static DateTime parseRequired(Object? value, {required String fieldName}) {
    if (value is! String) {
      throw FormatException('$fieldName must be a valid ISO-8601 string');
    }

    try {
      return DateTime.parse(value);
    } on FormatException {
      throw FormatException('$fieldName must be a valid ISO-8601 string');
    }
  }
}
