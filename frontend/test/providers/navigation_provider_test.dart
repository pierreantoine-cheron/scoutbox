import 'package:flutter_test/flutter_test.dart';
import 'package:client/providers/navigation_provider.dart';

void main() {
  test('catalogue navigation names the two kinds of modèle', () {
    expect(NavigationSection.parts.label, 'Modèles de pièce');
    expect(NavigationSection.models.label, 'Modèles de tente');
  });
}
