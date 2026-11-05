import 'package:app_map/app_map.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_platform_interface/maplibre_platform_interface.dart';
import 'package:nose_track/app.dart';
import 'package:nose_track/dev/phone_preview.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real map loads, moves, resets north and changes style', (
    tester,
  ) async {
    await tester.pumpWidget(const NoseTrackApp());
    await tester.pump();
    expect(find.byType(AppMap), findsOneWidget);
    final state = tester.state<MapLibreMapState>(find.byType(MapLibreMap));
    await _waitFor(tester, () => state.isInitialized && state.style != null);
    await _waitFor(tester, () => state.camera != null);
    await tester.pump();
    expect(find.text('© OpenStreetMap'), findsOneWidget);
    expect(find.text('© OpenMapTiles'), findsOneWidget);

    const center = Geographic(lon: 6.13, lat: 45.9);
    await state.moveCamera(center: center, zoom: 12, bearing: 75);
    await _waitFor(tester, () => (state.camera!.bearing - 75).abs() < 0.1);
    expect(state.camera!.center.lon, closeTo(center.lon, 0.0001));
    expect(state.camera!.center.lat, closeTo(center.lat, 0.0001));

    await state.animateCamera(
      bearing: 0,
      nativeDuration: const Duration(milliseconds: 200),
      webMaxDuration: const Duration(milliseconds: 200),
    );
    await _waitFor(tester, () => state.camera!.bearing.abs() < 0.1);
    expect(state.camera!.zoom, closeTo(12, 0.01));
    expect(state.camera!.center.lon, closeTo(center.lon, 0.0001));

    const alternative = '''{
      "version": 8,
      "sources": {},
      "layers": [{
        "id": "test-background", "type": "background",
        "paint": {"background-color": "#d8e8d0"}
      }]
    }''';
    final initialStyle = state.style;
    state.setStyle(alternative);
    await _waitFor(
      tester,
      () => state.style != null && state.style != initialStyle,
    );
    expect(state.camera!.center.lon, closeTo(center.lon, 0.0001));
    expect(state.camera!.zoom, closeTo(12, 0.01));

    final alternativeStyle = state.style;
    state.setStyle('https://tiles.openfreemap.org/styles/liberty');
    await _waitFor(
      tester,
      () => state.style != null && state.style != alternativeStyle,
    );

    if (find.byType(PhonePreview).evaluate().isNotEmpty) {
      final profile = find.byKey(const ValueKey('preview-iphoneSE'));
      await tester.ensureVisible(profile);
      await tester.tap(profile);
      await tester.pump();
      expect(
        tester.state<MapLibreMapState>(find.byType(MapLibreMap)),
        same(state),
      );
      expect(state.camera!.center.lon, closeTo(center.lon, 0.0001));
    }
    expect(tester.takeException(), isNull);
  });
}

Future<void> _waitFor(WidgetTester tester, bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Map did not reach the expected state within 45 seconds.');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}
