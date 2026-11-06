import '../location/location_fix.dart';

class TrackPoint {
  TrackPoint.fromMap(Map map)
    : sequence = (map['sequence']! as num).toInt(),
      segmentId = (map['segmentId']! as num).toInt(),
      fix = LocationFix.fromMap(map);
  final int sequence;
  final int segmentId;
  final LocationFix fix;
}
