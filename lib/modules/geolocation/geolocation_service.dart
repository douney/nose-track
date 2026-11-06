import 'dart:async';

import '../../platform/tracking_backend.dart';
import 'location_models.dart';

export 'location_models.dart';

/// App-owned facade. Listening never controls native acquisition.
class GeolocationService {
  GeolocationService({TrackingBackend? backend})
    : _backend = backend ?? TrackingBackend.instance;

  final TrackingBackend _backend;

  Future<void> initialize() => _backend.initialize();

  Future<void> setMode(GeolocationMode mode, {RecordingTarget? target}) async {
    if ((mode == GeolocationMode.tracking) != (target != null)) {
      throw ArgumentError('Only tracking requires a recording target.');
    }
    await _backend.invoke<void>('setMode', {
      'mode': mode.name,
      'target': target?.toMap(),
    });
  }

  Stream<GeolocationState> get state => Stream.multi((controller) {
    var emitted = false;
    final subscription = _backend.events.listen((event) {
      if (event['type'] == 'state') {
        emitted = true;
        controller.add(GeolocationState.fromMap(event['data']! as Map));
      }
    }, onError: controller.addError);
    controller.onCancel = subscription.cancel;
    final current = _backend.currentState;
    if (current != null) {
      emitted = true;
      controller.add(GeolocationState.fromMap(current));
    }
    unawaited(
      initialize()
          .then((_) {
            if (!emitted) {
              controller.add(GeolocationState.fromMap(_backend.currentState!));
            }
          })
          .catchError(
            (Object error, StackTrace stack) =>
                controller.addError(error, stack),
          ),
    );
  }, isBroadcast: true);

  Stream<LocationFix> get positions => _backend.events
      .where((event) => event['type'] == 'position')
      .map((event) => LocationFix.fromMap(event['data']! as Map));

  LocationFix? get lastPosition =>
      _backend.lastFix == null ? null : LocationFix.fromMap(_backend.lastFix!);

  Stream<HeadingSample> get headings => _backend.events
      .where((event) => event['type'] == 'heading')
      .map((event) => HeadingSample.fromMap(event['data']! as Map));
}
