enum TrackRole { tracer, dog }

enum TraceStatus { recording, interrupted, finished }

class RecordingTarget {
  const RecordingTarget({required this.trackId, required this.role});

  final String trackId;
  final TrackRole role;

  Map<String, Object> toMap() => {'trackId': trackId, 'role': role.name};

  factory RecordingTarget.fromMap(Map<Object?, Object?> map) => RecordingTarget(
    trackId: map['trackId']! as String,
    role: TrackRole.values.byName(map['role']! as String),
  );

  @override
  bool operator ==(Object other) =>
      other is RecordingTarget &&
      other.trackId == trackId &&
      other.role == role;

  @override
  int get hashCode => Object.hash(trackId, role);
}
