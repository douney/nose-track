import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nose_track/dev/phone_preview.dart';

void main() {
  testWidgets('presets preserve state and keep dialogs in the phone viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(720, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      PhonePreview(
        builder: (platform) => MaterialApp(
          theme: ThemeData(platform: platform),
          home: const _PreviewScreen(),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('increment')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('dialog')));
    await tester.pumpAndSettle();

    for (final device in PreviewDevice.values) {
      final option = find.byKey(ValueKey('preview-${device.name}'));
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pumpAndSettle();

      final screen = find.byType(_PreviewScreen);
      final context = tester.element(screen);
      expect(tester.getSize(screen), device.size);
      expect(MediaQuery.sizeOf(context), device.size);
      expect(MediaQuery.paddingOf(context), device.safeArea);
      expect(Theme.of(context).platform, device.platform);
      expect(defaultTargetPlatform, TargetPlatform.macOS);
      expect(find.text('1'), findsOneWidget);

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(MediaQuery.sizeOf(tester.element(dialog)), device.size);
      final viewport = tester.getRect(screen);
      final rect = tester.getRect(dialog);
      expect(viewport.contains(rect.topLeft), isTrue);
      expect(rect.right, lessThanOrEqualTo(viewport.right));
      expect(rect.bottom, lessThanOrEqualTo(viewport.bottom));
      expect(tester.takeException(), isNull);
    }

    Navigator.of(tester.element(find.byType(AlertDialog))).pop();
    await tester.pumpAndSettle();
    final free = find.byKey(const Key('preview-free'));
    await tester.scrollUntilVisible(free, -200);
    await tester.tap(free);
    await tester.pumpAndSettle();

    for (final size in [const Size(320, 480), const Size(430, 932)]) {
      tester.view.physicalSize = Size(
        size.width + PhonePreview.panelWidth + 1 + PhonePreview.padding * 2,
        size.height + PhonePreview.padding * 2,
      );
      await tester.pumpAndSettle();
      final screen = find.byType(_PreviewScreen);
      expect(tester.getSize(screen), size);
      expect(MediaQuery.sizeOf(tester.element(screen)), size);
      expect(find.text('1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}

class _PreviewScreen extends StatefulWidget {
  const _PreviewScreen();

  @override
  State<_PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<_PreviewScreen> {
  int count = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Text('$count'),
          FilledButton(
            key: const Key('increment'),
            onPressed: () => setState(() => count++),
            child: const Text('Increment'),
          ),
          FilledButton(
            key: const Key('dialog'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const AlertDialog(content: Text('Preview')),
            ),
            child: const Text('Dialog'),
          ),
        ],
      ),
    ),
  );
}
