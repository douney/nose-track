import '../../domain/location/location_fix.dart';

export '../../domain/location/location_fix.dart';
import '../../domain/tracks/track_role.dart';

export '../../domain/tracks/track_role.dart';

class HeadingSample {
  const HeadingSample({
    required this.timestamp,
    this.headingDegrees,
    this.accuracyDegrees,
  });
  final DateTime timestamp;
  final double? headingDegrees;
  final double? accuracyDegrees;

  factory HeadingSample.fromMap(Map<Object?, Object?> map) => HeadingSample(
    timestamp: locationDate(map['timestamp']!),
    headingDegrees: (map['headingDegrees'] as num?)?.toDouble(),
    accuracyDegrees: (map['accuracyDegrees'] as num?)?.toDouble(),
  );
}

enum GeolocationMode { off, foreground, tracking }

enum AcquisitionStatus { stopped, waitingForFix, receiving, unavailable }

class TrackingIssue {
  const TrackingIssue(this.code, this.message);
  final String code;
  final String message;

  factory TrackingIssue.fromMap(Map<Object?, Object?> map) =>
      TrackingIssue(map['code']! as String, map['message']! as String);
}

class TrackingSession {
  const TrackingSession({
    required this.target,
    required this.startedAt,
    required this.status,
    this.endedAt,
  });
  final RecordingTarget target;
  final DateTime startedAt;
  final DateTime? endedAt;
  final TraceStatus status;

  factory TrackingSession.fromMap(Map<Object?, Object?> map) => TrackingSession(
    target: RecordingTarget.fromMap(map),
    startedAt: locationDate(map['startedAt']!),
    endedAt: map['endedAt'] == null ? null : locationDate(map['endedAt']!),
    status: TraceStatus.values.byName(map['status']! as String),
  );
}

class GeolocationState {
  const GeolocationState({
    required this.mode,
    required this.acquisitionStatus,
    this.session,
    this.issue,
  });
  final GeolocationMode mode;
  final AcquisitionStatus acquisitionStatus;
  final TrackingSession? session;
  final TrackingIssue? issue;

  factory GeolocationState.fromMap(Map<Object?, Object?> map) =>
      GeolocationState(
        mode: GeolocationMode.values.byName(map['mode']! as String),
        acquisitionStatus: AcquisitionStatus.values.byName(
          map['acquisitionStatus']! as String,
        ),
        session: map['session'] == null
            ? null
            : TrackingSession.fromMap(map['session']! as Map),
        issue: map['issue'] == null
            ? null
            : TrackingIssue.fromMap(map['issue']! as Map),
      );
}
