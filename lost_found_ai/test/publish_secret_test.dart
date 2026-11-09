import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:lost_found_ai/core/app_strings.dart';
import 'package:lost_found_ai/data/models/item.dart';
import 'package:lost_found_ai/features/publish/publish_screen.dart';
import 'package:lost_found_ai/widgets/app_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Uint8List photoBytes;

  setUpAll(() {
    photoBytes = File('web/favicon.png').readAsBytesSync();
  });

  setUp(() {
    ImagePickerPlatform.instance = _FakeImagePicker(photoBytes);
  });

  testWidgets('a lost item asks for a secret detail', (tester) async {
    await tester.pumpWidget(_app(ItemType.lost));
    await _goToDetails(tester);

    expect(find.text('Détail secret de vérification'), findsOneWidget);
    expect(find.textContaining('Détail secret'), findsOneWidget);
  });

  testWidgets('a found item does not ask for a secret detail', (tester) async {
    await tester.pumpWidget(_app(ItemType.found));
    await _goToDetails(tester);

    expect(find.text('Détail secret de vérification'), findsNothing);
  });

  testWidgets('a lost item cannot continue without its secret detail', (
    tester,
  ) async {
    await tester.pumpWidget(_app(ItemType.lost));
    await _goToDetails(tester);

    await tester.tap(find.text('Sac'));
    await tester.enterText(find.byType(TextField).at(0), 'Sac a dos noir Nike');
    await tester.enterText(
      find.byType(TextField).at(1),
      'Sac perdu avec une bande rouge et une etiquette bleue.',
    );
    await tester.pump();

    expect(_continueButton(tester).onPressed, isNull);

    await tester.enterText(
      find.byType(TextField).at(2),
      'Etiquette bleue a l interieur',
    );
    await tester.pump();

    expect(_continueButton(tester).onPressed, isNotNull);
  });
}

class _FakeImagePicker extends ImagePickerPlatform {
  _FakeImagePicker(this.bytes);

  final Uint8List bytes;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    return XFile.fromData(bytes, name: 'photo.png', mimeType: 'image/png');
  }
}

Widget _app(ItemType type) {
  return ProviderScope(
    child: MaterialApp(home: PublishScreen(initialType: type)),
  );
}

AppButton _continueButton(WidgetTester tester) {
  return tester.widget<AppButton>(
    find.widgetWithText(AppButton, 'Suivant'),
  );
}

Future<void> _goToDetails(WidgetTester tester) async {
  await tester.tap(find.text(AppStrings.photoDropzone));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Choisir dans la galerie'));
  await tester.pumpAndSettle();

  expect(find.text('Photo ajoutée'), findsOneWidget);

  await tester.tap(find.text('Suivant'));
  await tester.pumpAndSettle();

  expect(find.text(AppStrings.stepDetailsTitle), findsOneWidget);
}
