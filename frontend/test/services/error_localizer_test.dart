import 'package:flutter_test/flutter_test.dart';
import 'package:client/services/error_localizer.dart';
import 'package:client/utils/constants.dart';

void main() {
  test('localizes tent model name validation errors', () {
    expect(
      ErrorLocalizer.localize(ErrorCodes.modelNameRequired),
      'Le nom du modèle de tente doit contenir au moins 2 caractères.',
    );
    expect(
      ErrorLocalizer.localize(ErrorCodes.modelNameTooLong),
      'Le nom du modèle de tente doit contenir 60 caractères maximum.',
    );
  });

  test('localizes modèle de pièce errors', () {
    expect(
      ErrorLocalizer.localize(ErrorCodes.invalidPartKind),
      'Modèle de pièce invalide.',
    );
    expect(
      ErrorLocalizer.localize(ErrorCodes.partKindNameExists),
      'Un modèle de pièce avec ce nom existe déjà',
    );
    expect(
      ErrorLocalizer.localize(ErrorCodes.partKindNameRequired),
      'Le nom du modèle de pièce est requis',
    );
    expect(
      ErrorLocalizer.localize(ErrorCodes.partKindNameTooLong),
      'Le nom du modèle de pièce est trop long (60 max)',
    );
    expect(
      ErrorLocalizer.localize(ErrorCodes.partKindNotFound),
      'Modèle de pièce introuvable',
    );
  });

  test('localizes modèle de tente errors', () {
    expect(
      ErrorLocalizer.localize(ErrorCodes.tentModelNotFound),
      'Ce modèle de tente est introuvable.',
    );
    expect(
      ErrorLocalizer.localize(ErrorCodes.modelInUse),
      'Impossible de supprimer ce modèle de tente car des tentes l\'utilisent encore.',
    );
    expect(
      ErrorLocalizer.localize(ErrorCodes.modelNameExists),
      'Un modèle de tente avec ce nom existe déjà.',
    );
  });
}
