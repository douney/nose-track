import 'dart:async';

import '../../platform/tracking_backend.dart';
import 'track_models.dart';

export 'track_models.dart';

class TrackRepository {
  TrackRepository({TrackingBackend? backend})
    : _backend = backend ?? TrackingBackend.instance;
  final TrackingBackend _backend;

  Future<TrackInfo> createTrack({
    required String name,
    String? description,
    String? dogName,
  }) async => TrackInfo.fromRow(
    (await _backend.invoke<Map>('createTrack', {
      'name': name,
      'description': description,
      'dog_name': dogName,
    }))!,
  );

  Future<List<TrackInfo>> listTracks({TrackFilter? filter}) async =>
      (await _backend.invoke<List>(
        'listTracks',
        filter?.toMap(),
      ))!.map((row) => TrackInfo.fromRow(row as Map)).toList(growable: false);

  Future<TrackInfo?> getTrack(String trackId) async {
    final row = await _backend.invoke<Map>('getTrack', {'trackId': trackId});
    return row == null ? null : TrackInfo.fromRow(row);
  }

  Future<TrackInfo> updateTrack(String trackId, TrackChanges changes) async =>
      TrackInfo.fromRow(
        (await _backend.invoke<Map>('updateTrack', {
          'trackId': trackId,
          'changes': changes.toMap(),
        }))!,
      );

  Future<void> deleteTrack(String trackId) =>
      _backend.invoke<void>('deleteTrack', {'trackId': trackId});

  /// Imports the versioned NoseTrack JSONL format, preserving the source file.
  Future<TrackInfo> importTrace(
    String trackId,
    TrackRole role,
    String source,
  ) async => TrackInfo.fromRow(
    (await _backend.invoke<Map>('importTrace', {
      'trackId': trackId,
      'role': role.name,
      'source': source,
    }))!,
  );

  Stream<TrackPoint> readTrack(
    String trackId,
    TrackRole role, {
    int afterSequence = 0,
    bool follow = false,
  }) {
    if (afterSequence < 0) {
      throw ArgumentError.value(afterSequence, 'afterSequence');
    }
    return _TrackReader(_backend, trackId, role, afterSequence, follow).stream;
  }
}

/// Subscribes before reading. A generation counter closes the history/live race.
/// Cancellation wakes pending reads, and pause prevents unbounded history loads.
class _TrackReader {
  _TrackReader(this.backend, this.id, this.role, this.after, this.follow) {
    controller = StreamController<TrackPoint>(
      onListen: () => unawaited(_run()),
      onCancel: () {
        cancelled = true;
        _wake();
      },
      onPause: () => paused = true,
      onResume: () {
        paused = false;
        _wake();
      },
    );
  }
  final TrackingBackend backend;
  final String id;
  final TrackRole role;
  final int after;
  final bool follow;
  late final StreamController<TrackPoint> controller;
  Stream<TrackPoint> get stream => controller.stream;
  bool cancelled = false;
  bool paused = false;
  int generation = 0;
  Completer<void>? waiter;

  void _wake() {
    generation++;
    waiter?.complete();
    waiter = null;
  }

  Future<void> _wait() => (waiter ??= Completer<void>()).future;

  Future<void> _run() async {
    final subscription = backend.events.listen(
      (event) {
        if (event['type'] == 'journal' || event['type'] == 'state') _wake();
      },
      onError: (Object error, StackTrace stack) {
        if (!cancelled) controller.addError(error, stack);
        _wake();
      },
    );
    var offset = 0;
    try {
      while (!cancelled) {
        while (paused && !cancelled) {
          await _wait();
        }
        if (cancelled) break;
        final before = generation;
        final chunk = (await backend.invoke<Map>('readTrack', {
          'trackId': id,
          'role': role.name,
          'offset': offset,
          'afterSequence': after,
        }))!;
        offset = (chunk['offset']! as num).toInt();
        for (final point in chunk['points']! as List) {
          while (paused && !cancelled) {
            await _wait();
          }
          if (cancelled) break;
          controller.add(TrackPoint.fromMap(point as Map));
        }
        if (chunk['eof'] != true) continue;
        if (!follow || chunk['status'] != 'recording') break;
        if (generation == before && !cancelled) await _wait();
      }
    } catch (error, stack) {
      if (!cancelled) controller.addError(error, stack);
    } finally {
      await subscription.cancel();
      if (!controller.isClosed) unawaited(controller.close());
    }
  }
}
