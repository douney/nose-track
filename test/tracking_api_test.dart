import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nose_track/data/tracks/track_repository.dart';
import 'package:nose_track/modules/geolocation/geolocation_service.dart';
import 'package:nose_track/platform/tracking_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('test/tracking');
  late StreamController<Map<Object?, Object?>> events;
  late TrackingBackend backend;
  late List<MethodCall> calls;
  late Future<Object?> Function(MethodCall) handle;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final idle = <String, Object?>{
    'mode': 'off',
    'acquisitionStatus': 'stopped',
    'session': null,
    'issue': null,
  };

  setUp(() {
    events = StreamController.broadcast(sync: true);
    backend = TrackingBackend(
      methods: methods,
      events: events.stream,
      loadSchema: () async => 'schema',
    );
    calls = [];
    handle = (call) async => switch (call.method) {
      'initialize' => {'state': idle, 'lastPosition': null},
      _ => null,
    };
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      return handle(call);
    });
  });
  tearDown(() async {
    await backend.dispose();
    await events.close();
    messenger.setMockMethodCallHandler(methods, null);
  });

  test('initial state, multiple listeners and cached fix never control acquisition', () async {
    final service = GeolocationService(backend: backend);
    expect((await service.state.first).mode, GeolocationMode.off);
    expect((await service.state.first).mode, GeolocationMode.off);
    final a = service.positions.first;
    final b = service.positions.first;
    events.add({
      'type': 'position',
      'data': {'timestamp': 1000, 'latitude': 48.0, 'longitude': 2.0},
    });
    expect((await a).latitude, 48);
    expect((await b).timestamp.isUtc, isTrue);
    expect(service.lastPosition!.timestamp.millisecondsSinceEpoch, 1000);
    expect(calls.map((c) => c.method), ['initialize']);
  });

  test(
    'target is required only for tracking and passed without hidden commands',
    () async {
      final service = GeolocationService(backend: backend);
      await expectLater(
        service.setMode(GeolocationMode.tracking),
        throwsArgumentError,
      );
      const target = RecordingTarget(trackId: 'id', role: TrackRole.dog);
      await service.setMode(GeolocationMode.tracking, target: target);
      expect(calls.last.arguments, {
        'mode': 'tracking',
        'target': {'trackId': 'id', 'role': 'dog'},
      });
      await expectLater(
        service.setMode(GeolocationMode.foreground, target: target),
        throwsArgumentError,
      );
    },
  );

  test('resume snapshots cannot roll back a newer state or position', () async {
    await backend.initialize();
    events.add({
      'type': 'state',
      'data': {...idle, 'mode': 'foreground', 'revision': 4},
    });
    events.add({'type': 'position', 'data': _point(3)});
    handle = (_) async => {
      'state': {...idle, 'revision': 2},
      'lastPosition': _point(1),
    };
    backend.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(backend.currentState!['mode'], 'foreground');
    expect(
      GeolocationService(backend: backend)
          .lastPosition!
          .timestamp
          .millisecondsSinceEpoch,
      3000,
    );
  });

  test(
    'initialization can retry a native error without starting any mode',
    () async {
      var attempts = 0;
      handle = (_) async {
        attempts++;
        if (attempts == 1) throw PlatformException(code: 'storageError');
        return {'state': idle, 'lastPosition': null};
      };
      await expectLater(
        backend.initialize(),
        throwsA(isA<PlatformException>()),
      );
      await backend.initialize();
      expect(attempts, 2);
      expect(calls.every((c) => c.method == 'initialize'), isTrue);
    },
  );

  test('unknown heading stays null and north stays zero', () async {
    await backend.initialize();
    final samples = GeolocationService(backend: backend).headings
        .take(2)
        .toList();
    events.add({
      'type': 'heading',
      'data': {'timestamp': 1000, 'headingDegrees': null},
    });
    events.add({
      'type': 'heading',
      'data': {'timestamp': 1100, 'headingDegrees': 0.0},
    });
    expect((await samples).map((s) => s.headingDegrees), [null, 0.0]);
  });

  test('metadata patch distinguishes null from absent', () {
    final changes = TrackChanges()
      ..description = null
      ..dogName = 'Nala';
    expect(changes.toMap(), {'description': null, 'dog_name': 'Nala'});
    expect(() => changes.toMap()['name'] = 'x', throwsUnsupportedError);
  });

  test('following subscribes before history and catches append during initial read', () async {
    var reads = 0;
    handle = (call) async {
      if (call.method == 'initialize') {
        return {'state': idle, 'lastPosition': null};
      }
      if (call.method == 'readTrack') {
        reads++;
        if (reads == 1) {
          events.add({'type': 'journal'});
          return {
            'points': [_point(1)],
            'offset': 100,
            'eof': true,
            'status': 'recording',
          };
        }
        return {
          'points': [_point(2)],
          'offset': 200,
          'eof': true,
          'status': 'finished',
        };
      }
      return null;
    };
    final points = await TrackRepository(backend: backend)
        .readTrack('id', TrackRole.tracer, follow: true)
        .toList();
    expect(points.map((p) => p.sequence), [1, 2]);
    expect(reads, 2);
    expect(calls.last.arguments['offset'], 100);
  });

  test(
    'cancelling a live reader wakes it and releases its subscription',
    () async {
      var reads = 0;
      final read = Completer<void>();
      handle = (call) async {
        if (call.method == 'initialize') {
          return {'state': idle, 'lastPosition': null};
        }
        if (call.method == 'readTrack') {
          reads++;
          if (!read.isCompleted) read.complete();
          return {
            'points': [],
            'offset': 0,
            'eof': true,
            'status': 'recording',
          };
        }
        return null;
      };
      final sub = TrackRepository(backend: backend)
          .readTrack('id', TrackRole.dog, follow: true)
          .listen((_) {});
      await read.future;
      await sub.cancel().timeout(const Duration(seconds: 1));
      final before = reads;
      events.add({'type': 'journal'});
      await Future<void>.delayed(Duration.zero);
      expect(reads, before);
    },
  );
}

Map<String, Object> _point(int sequence) => {
  'type': 'point',
  'sequence': sequence,
  'segmentId': 1,
  'timestamp': sequence * 1000,
  'latitude': 48.0,
  'longitude': 2.0,
};
