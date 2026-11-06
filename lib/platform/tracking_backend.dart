import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The only Flutter/native transport. No product model or SQL lives here.
class TrackingBackend with WidgetsBindingObserver {
  TrackingBackend({
    MethodChannel? methods,
    Stream<Map<Object?, Object?>>? events,
    Future<String> Function()? loadSchema,
  }) : _methods = methods ?? const MethodChannel('nose_track/tracking'),
       _source =
           events ??
           const EventChannel('nose_track/tracking/events')
               .receiveBroadcastStream()
               .map((event) => Map<Object?, Object?>.from(event as Map)),
       _loadSchema =
           loadSchema ??
           (() => rootBundle.loadString('assets/sql/tracks_v1.sql'));

  static final instance = TrackingBackend();
  final MethodChannel _methods;
  final Stream<Map<Object?, Object?>> _source;
  final Future<String> Function() _loadSchema;
  final _events = StreamController<Map<Object?, Object?>>.broadcast(sync: true);
  Future<void>? _initializing;
  StreamSubscription<Map<Object?, Object?>>? _subscription;
  Map<Object?, Object?>? currentState;
  Map<Object?, Object?>? lastFix;
  int _revision = -1;

  Stream<Map<Object?, Object?>> get events => _events.stream;

  /// Detaches this Flutter transport only; native recording is unaffected.
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _subscription?.cancel();
    await _events.close();
  }

  Future<void> initialize() =>
      _initializing ??= _initialize().catchError((Object error) {
        _initializing = null;
        throw error;
      });

  Future<void> _initialize() async {
    _subscription ??= _source.listen(_accept, onError: _events.addError);
    final snapshot = await _methods.invokeMapMethod<Object?, Object?>(
      'initialize',
      {'schema': await _loadSchema()},
    );
    _snapshot(snapshot!);
    WidgetsBinding.instance.addObserver(this);
  }

  void _accept(Map<Object?, Object?> event) {
    if (event['type'] == 'state') {
      final state = event['data']! as Map;
      final revision = (state['revision'] as num?)?.toInt();
      if (revision != null && revision < _revision) return;
      if (revision != null) _revision = revision;
      currentState = state;
    }
    if (event['type'] == 'position') _rememberFix(event['data']! as Map);
    _events.add(event);
  }

  void _rememberFix(Map<Object?, Object?>? fix) {
    if (fix != null &&
        (lastFix == null ||
            (fix['timestamp']! as num) >= (lastFix!['timestamp']! as num))) {
      lastFix = fix;
    }
  }

  void _snapshot(Map<Object?, Object?> snapshot) {
    _rememberFix(snapshot['lastPosition'] as Map?);
    _accept({'type': 'state', 'data': snapshot['state']});
    _events.add({'type': 'journal'});
  }

  Future<T?> invoke<T>(String method, [Map<String, Object?>? arguments]) async {
    await initialize();
    return _methods.invokeMethod<T>(method, arguments);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _initializing != null) {
      unawaited(
        invoke<Map>('getSnapshot')
            .then((value) => _snapshot(value!))
            .catchError(
              (Object error, StackTrace stack) =>
                  _events.addError(error, stack),
            ),
      );
    }
  }
}
