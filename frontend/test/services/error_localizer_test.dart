import 'package:flutter_test/flutter_test.dart';
import 'package:client/services/error_localizer.dart';
import 'package:client/utils/constants.dart';

void main() {
  test('localizes tent model name validation errors', () {
    expect(
      ErrorLocalizer.localize(ErrorCodes.modelNameRequired),
      'Le nom du modèle doit contenir au moins 2 caractères.',
    );
    expect(
      ErrorLocalizer.localize(ErrorCodes.modelNameTooLong),
      'Le nom du modèle doit contenir 60 caractères maximum.',
    );
  });
}
