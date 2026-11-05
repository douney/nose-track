import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nose_track/app.dart';
import 'package:nose_track/dev/phone_preview.dart';
import 'package:nose_track/home_screen.dart';

void main() {
  testWidgets(
    'phones display the app directly at compact and landscape sizes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      for (final size in [const Size(320, 480), const Size(568, 320)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(const NoseTrackApp());
        await tester.pumpAndSettle();

        expect(find.byType(PhonePreview), findsNothing);
        expect(find.text('Mantrailing'), findsOneWidget);
        expect(tester.getSize(find.byType(HomeScreen)), size);
        expect(tester.takeException(), isNull);
      }
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets('Mac launches the app inside the phone preview', (tester) async {
    await tester.pumpWidget(const NoseTrackApp());

    expect(find.byType(PhonePreview), findsOneWidget);
    expect(find.text('Mantrailing'), findsOneWidget);
    expect(
      MediaQuery.sizeOf(tester.element(find.byType(HomeScreen))),
      PreviewDevice.iphone14.size,
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
