DateTime locationDate(Object value) =>
    DateTime.fromMillisecondsSinceEpoch((value as num).toInt(), isUtc: true);

class LocationFix {
  const LocationFix({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.altitudeMeters,
    this.speedMetersPerSecond,
    this.courseDegrees,
  });

  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;

  /// Height above the WGS84 ellipsoid, not mean sea level.
  final double? altitudeMeters;
  final double? speedMetersPerSecond;
  final double? courseDegrees;

  factory LocationFix.fromMap(Map<Object?, Object?> map) => LocationFix(
    timestamp: locationDate(map['timestamp']!),
    latitude: (map['latitude']! as num).toDouble(),
    longitude: (map['longitude']! as num).toDouble(),
    accuracyMeters: (map['accuracyMeters'] as num?)?.toDouble(),
    altitudeMeters: (map['altitudeMeters'] as num?)?.toDouble(),
    speedMetersPerSecond: (map['speedMetersPerSecond'] as num?)?.toDouble(),
    courseDegrees: (map['courseDegrees'] as num?)?.toDouble(),
  );
}
