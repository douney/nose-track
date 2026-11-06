import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nose_track/data/tracks/track_repository.dart';
import 'package:nose_track/modules/geolocation/geolocation_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native catalogue and both journals work through the Flutter bridge',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Text('Tracking storage check')),
      );
      final location = GeolocationService();
      final tracks = TrackRepository();
      await location.initialize();
      final source = File(
        '${Directory.systemTemp.path}/nose-track-${DateTime.now().microsecondsSinceEpoch}.jsonl',
      );
      String? id;
      try {
        final track = await tracks.createTrack(
          name: 'Forêt 🐕',
          dogName: 'Nala',
        );
        id = track.id;
        expect(track.tracer, isNull);
        expect(track.dogName, 'Nala');
        final changes = TrackChanges()
          ..description = 'Chemin'
          ..dogName = null;
        final changed = await tracks.updateTrack(id, changes);
        expect(changed.name, track.name);
        expect(changed.dogName, isNull);
        final records = <Map<String, Object?>>[
          {
            'type': 'header',
            'version': 1,
            'trackId': id,
            'role': 'tracer',
            'startedAt': 1000,
          },
          for (var i = 1; i <= 300; i++)
            {
              'type': 'point',
              'sequence': i,
              'segmentId': 1,
              'timestamp': i * 1000,
              'latitude': 48.1,
              'longitude': 2.3,
              'accuracyMeters': 4.0,
            },
          {'type': 'end', 'endedAt': 301000},
        ];
        await source.writeAsString(
          '${records.map(jsonEncode).join('\n')}\n',
          flush: true,
        );
        await tracks.importTrace(id, TrackRole.tracer, source.path);
        final both = await tracks.importTrace(id, TrackRole.dog, source.path);
        expect(both.tracer!.pointCount, 300);
        expect(both.dog!.status, TraceStatus.finished);
        final points = await tracks
            .readTrack(id, TrackRole.dog, afterSequence: 125)
            .toList();
        expect(
          points.map((p) => p.sequence),
          orderedEquals(List.generate(175, (i) => i + 126)),
        );
        expect(await source.exists(), isTrue);
        expect(
          (await tracks.listTracks(
            filter: const TrackFilter(hasTracer: true, hasDog: true),
          )).any((t) => t.id == id),
          isTrue,
        );
        await expectLater(
          tracks.importTrace(id, TrackRole.dog, source.path),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'traceAlreadyExists',
            ),
          ),
        );
        if (Platform.isMacOS) {
          await expectLater(
            location.setMode(
              GeolocationMode.tracking,
              target: RecordingTarget(trackId: id, role: TrackRole.tracer),
            ),
            throwsA(
              isA<PlatformException>().having(
                (e) => e.code,
                'code',
                'unsupportedPlatform',
              ),
            ),
          );
        }
        await tracks.deleteTrack(id);
        expect(await tracks.getTrack(id), isNull);
        id = null;
      } finally {
        if (id != null) await tracks.deleteTrack(id);
        if (await source.exists()) await source.delete();
      }
    },
  );
}
