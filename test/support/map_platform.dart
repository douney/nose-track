import 'package:flutter/widgets.dart';
import 'package:maplibre_platform_interface/maplibre_platform_interface.dart';

/// Skips the native renderer in layout tests; integration tests use the real map.
class TestMapPlatform extends MapLibrePlatform {
  @override
  MapLibreMapState createWidgetState() => _TestMapState();
}

class _TestMapState extends MapLibreMapState {
  @override
  Widget buildPlatformWidget(BuildContext context) => const SizedBox.expand();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
