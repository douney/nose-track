import '../../domain/location/location_fix.dart';
import '../../domain/tracks/track_role.dart';

export '../../domain/tracks/track_role.dart';
export '../../domain/tracks/track_point.dart';

class GpsTraceInfo {
  const GpsTraceInfo({
    required this.fileName,
    required this.startedAt,
    required this.status,
    required this.pointCount,
    this.endedAt,
    this.startLatitude,
    this.startLongitude,
  });
  final String fileName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final TraceStatus status;
  final int pointCount;
  final double? startLatitude;
  final double? startLongitude;

  static GpsTraceInfo? fromRow(Map row, TrackRole role) {
    final prefix = role.name;
    if (row['${prefix}_status'] == null) return null;
    return GpsTraceInfo(
      fileName: row['${prefix}_file_name']! as String,
      startedAt: locationDate(row['${prefix}_started_at']!),
      endedAt: row['${prefix}_ended_at'] == null
          ? null
          : locationDate(row['${prefix}_ended_at']!),
      status: TraceStatus.values.byName(row['${prefix}_status']! as String),
      pointCount: (row['${prefix}_point_count']! as num).toInt(),
      startLatitude: (row['${prefix}_start_latitude'] as num?)?.toDouble(),
      startLongitude: (row['${prefix}_start_longitude'] as num?)?.toDouble(),
    );
  }
}

class TrackInfo {
  TrackInfo.fromRow(Map row)
    : id = row['id']! as String,
      name = row['name']! as String,
      description = row['description'] as String?,
      dogName = row['dog_name'] as String?,
      createdAt = locationDate(row['created_at']!),
      updatedAt = locationDate(row['updated_at']!),
      tracer = GpsTraceInfo.fromRow(row, TrackRole.tracer),
      dog = GpsTraceInfo.fromRow(row, TrackRole.dog);

  final String id;
  final String name;
  final String? description;
  final String? dogName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final GpsTraceInfo? tracer;
  final GpsTraceInfo? dog;
}

/// Explicit patch: use the named setters to distinguish absent from null.
class TrackChanges {
  final Map<String, Object?> _values = {};
  set name(String value) => _values['name'] = value;
  set description(String? value) => _values['description'] = value;
  set dogName(String? value) => _values['dog_name'] = value;
  Map<String, Object?> toMap() => Map.unmodifiable(_values);
}

class TrackFilter {
  const TrackFilter({
    this.search,
    this.createdFrom,
    this.createdBefore,
    this.hasTracer,
    this.hasDog,
  });
  final String? search;
  final DateTime? createdFrom;
  final DateTime? createdBefore;
  final bool? hasTracer;
  final bool? hasDog;

  Map<String, Object?> toMap() => {
    'search': search,
    'createdFrom': createdFrom?.millisecondsSinceEpoch,
    'createdBefore': createdBefore?.millisecondsSinceEpoch,
    'hasTracer': hasTracer,
    'hasDog': hasDog,
  };
}
