import 'package:app_map/app_map.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_platform_interface/maplibre_platform_interface.dart';

const _style = '''{
  "version": 8, "sources": {},
  "layers": [{"id": "background", "type": "background",
    "paint": {"background-color": "#f0f0f0"}}]
}''';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('GeoJSON sources render, update, reload and remove on Mac', (
    tester,
  ) async {
    final controller = AppMapController();
    await controller.setGeoJson('live', _paths());
    await controller.setGeoJson('annotations', {
      'type': 'FeatureCollection',
      'features': [
        _feature(
          'point',
          {
            'type': 'Point',
            'coordinates': [6.132, 45.905],
          },
          {'color': '#8800ff', 'radius': 8},
        ),
        _feature(
          'zone',
          {
            'type': 'Polygon',
            'coordinates': [
              [
                [6.125, 45.895],
                [6.13, 45.895],
                [6.13, 45.897],
                [6.125, 45.895],
              ],
            ],
          },
          {'color': '#ff8800', 'fillOpacity': 0.5},
        ),
      ],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: AppMap(
          controller: controller,
          options: const MapOptions(
            initStyle: _style,
            initCenter: Geographic(lon: 6.13, lat: 45.9),
            initZoom: 14,
            maxPitch: 0,
          ),
        ),
      ),
    );
    final state = tester.state<MapLibreMapState>(find.byType(MapLibreMap));
    await _waitFor(tester, () => state.style != null && state.camera != null);
    final initial = await _waitForScene(
      tester,
      state,
      (scene) =>
          _names(scene).containsAll(['red', 'blue', 'dots', 'point', 'zone']),
    );
    expect(initial['sourceCount'], 2);
    final lineLayers = (initial['lines'] as List).cast<Map>();
    expect(
      lineLayers.any((line) => listEquals(line['dash'] as List?, [3, 2])),
      isTrue,
    );
    expect(
      lineLayers.any((line) => listEquals(line['dash'] as List?, [0, 2])),
      isTrue,
    );
    final center = state.camera!.center;

    await controller.setGeoJson('live', _paths(updated: true));
    final updated = await _waitForScene(tester, state, (scene) {
      final names = _names(scene);
      return names.containsAll(['Équipe 🐕', 'point', 'zone']) &&
          !names.contains('blue');
    });
    expect(updated['sourceCount'], 2);

    final previousStyle = state.style;
    state.setStyle(_style.replaceFirst('#f0f0f0', '#e0eee0'));
    await _waitFor(tester, () => state.style != previousStyle);
    final restored = await _waitForScene(
      tester,
      state,
      (scene) => _names(scene).containsAll(['Équipe 🐕', 'point', 'zone']),
    );
    expect(restored['sourceCount'], 2);

    await controller.removeGeoJson('live');
    final remaining = await _waitForScene(
      tester,
      state,
      (scene) =>
          scene['sourceCount'] == 1 && !_names(scene).contains('Équipe 🐕'),
    );
    expect(_names(remaining), containsAll(['point', 'zone']));
    await controller.removeGeoJson('annotations');
    await _waitForScene(tester, state, (scene) => scene['sourceCount'] == 0);

    await controller.setCursor(position: center, accuracyMeters: 25);
    await tester.pump();
    final dot = find.byKey(const ValueKey('app-map-cursor-dot'));
    final arrow = find.byKey(const ValueKey('app-map-cursor-heading'));
    expect(dot, findsOneWidget);
    expect(arrow, findsNothing);
    await _waitForScene(tester, state, (scene) => scene['hasAccuracy'] == true);
    final projected = state.toScreenLocation(center);
    final mapOrigin = tester.getTopLeft(find.byType(AppMap));
    expect(
      (tester.getCenter(dot) - mapOrigin - projected).distance,
      lessThan(0.1),
    );

    await controller.setCursor(
      position: center,
      heading: 90,
      accuracyMeters: 25,
    );
    await tester.pump();
    expect(dot, findsNothing);
    expect(arrow, findsOneWidget);
    var rotation = tester.widget<Transform>(
      find.byKey(const ValueKey('app-map-cursor-rotation')),
    );
    expect(rotation.transform.entry(1, 0), closeTo(1, 0.001));
    await state.moveCamera(bearing: 90);
    await _waitFor(tester, () => (state.camera!.bearing - 90).abs() < 0.1);
    await tester.pump();
    rotation = tester.widget<Transform>(
      find.byKey(const ValueKey('app-map-cursor-rotation')),
    );
    expect(rotation.transform.entry(1, 0), closeTo(0, 0.001));

    final cursorStyle = state.style;
    state.setStyle(_style);
    await _waitFor(tester, () => state.style != cursorStyle);
    await _waitForScene(tester, state, (scene) => scene['hasAccuracy'] == true);
    expect(arrow, findsOneWidget);
    await controller.setCursor(position: center, heading: null);
    await tester.pump();
    expect(dot, findsOneWidget);
    await _waitForScene(tester, state, (scene) => scene['sourceCount'] == 0);
    await controller.clearCursor();
    await tester.pump();
    expect(dot, findsNothing);
    expect(arrow, findsNothing);
    expect(state.camera!.center.lon, closeTo(center.lon, 0.000001));
    expect(state.camera!.center.lat, closeTo(center.lat, 0.000001));
    expect(
      tester.state<MapLibreMapState>(find.byType(MapLibreMap)),
      same(state),
    );
    expect(tester.takeException(), isNull);
  }, skip: defaultTargetPlatform != TargetPlatform.macOS);
}

Map<String, dynamic> _paths({bool updated = false}) => {
  'type': 'FeatureCollection',
  'features': [
    _feature(
      updated ? 'Équipe 🐕' : 'red',
      {
        'type': 'LineString',
        'coordinates': [
          [6.123, 45.902],
          [6.13, 45.904],
          [6.137, 45.902],
        ],
      },
      {'color': '#ff0000', 'width': updated ? 9 : 6, 'opacity': 0.8},
    ),
    if (!updated) ...[
      _feature(
        'blue',
        {
          'type': 'LineString',
          'coordinates': [
            [6.123, 45.9],
            [6.137, 45.9],
          ],
        },
        {'color': '#0000ff', 'width': 6, 'lineStyle': 'dashed'},
      ),
      _feature(
        'dots',
        {
          'type': 'MultiLineString',
          'coordinates': [
            [
              [6.123, 45.898],
              [6.128, 45.898],
            ],
            [
              [6.132, 45.898],
              [6.137, 45.898],
            ],
          ],
        },
        {'color': '#008800', 'width': 6, 'lineStyle': 'dotted'},
      ),
    ],
  ],
};

Map<String, dynamic> _feature(
  String name,
  Map<String, dynamic> geometry,
  Map<String, dynamic> properties,
) => {
  'type': 'Feature',
  'id': name,
  'properties': {'name': name, ...properties},
  'geometry': geometry,
};

Set<String> _names(Map<String, dynamic> scene) =>
    (scene['names'] as List).cast<String>().toSet();

Future<void> _waitFor(WidgetTester tester, bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Map did not become ready.');
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<Map<String, dynamic>> _waitForScene(
  WidgetTester tester,
  MapLibreMapState state,
  bool Function(Map<String, dynamic>) condition,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  Map<String, dynamic>? scene;
  while (DateTime.now().isBefore(deadline)) {
    // The desktop plugin does not expose featuresInRect yet. Query its real
    // MapLibre JS renderer here; this probe is confined to the Mac preview test.
    final dynamic webView = (state as dynamic).webViewController;
    final dynamic result = await webView.callAsyncJavaScript(
      functionBody: '''
      const style = window.map.getStyle();
      const sources = Object.keys(style.sources).filter(id => id.startsWith('app-map-'));
      const layers = style.layers.filter(layer => sources.includes(layer.source));
      return {
        sourceCount: sources.length,
        hasAccuracy: sources.some(id => {
          const data = style.sources[id].data;
          return data && data.features && data.features.some(feature => feature.id === 'app-map-cursor-accuracy');
        }),
        names: layers.length ? window.map.queryRenderedFeatures({layers: layers.map(l => l.id)})
          .map(feature => feature.properties.name).filter(Boolean) : [],
        lines: layers.filter(layer => layer.type === 'line').map(layer => ({
          dash: layer.paint['line-dasharray'] || null
        }))
      };
    ''',
    );
    expect(result?.error, isNull);
    scene = Map<String, dynamic>.from(result.value as Map);
    if (condition(scene)) return scene;
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('GeoJSON did not reach the expected rendered state: $scene');
}
