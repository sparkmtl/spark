import 'package:latlong2/latlong.dart';

import '../models/map_hot_zone.dart';
import '../models/map_user_model.dart';

/// Similarity score (see `map_view.dart`'s `similarityHeatColor`) above
/// which a user counts as a "relevant"/good match for hot-zone purposes.
const double relevantSimilarityThreshold = 0.6;

const Distance _distance = Distance();

/// Finds areas with a high concentration of users whose profile similarity
/// is at least [minSimilarity], by grouping them (great-circle distance)
/// within [mergeDistanceMeters] of each other. Zones with fewer than
/// [minUsersPerZone] members aren't considered a "concentration" and are
/// dropped.
List<MapHotZone> computeHotZones({
  required List<MapUserModel> users,
  double minSimilarity = relevantSimilarityThreshold,
  double mergeDistanceMeters = 1200,
  int minUsersPerZone = 2,
}) {
  final relevant = users.where((u) => u.similarity >= minSimilarity).toList();
  if (relevant.isEmpty) return const [];

  final visited = List<bool>.filled(relevant.length, false);
  final zones = <MapHotZone>[];

  for (var i = 0; i < relevant.length; i++) {
    if (visited[i]) continue;
    visited[i] = true;
    final members = <MapUserModel>[relevant[i]];
    var sumLat = relevant[i].latitude;
    var sumLng = relevant[i].longitude;

    for (var j = i + 1; j < relevant.length; j++) {
      if (visited[j]) continue;
      final centroid = LatLng(sumLat / members.length, sumLng / members.length);
      final candidate = LatLng(relevant[j].latitude, relevant[j].longitude);
      if (_distance(centroid, candidate) <= mergeDistanceMeters) {
        visited[j] = true;
        members.add(relevant[j]);
        sumLat += relevant[j].latitude;
        sumLng += relevant[j].longitude;
      }
    }

    if (members.length < minUsersPerZone) continue;

    zones.add(
      MapHotZone(
        center: LatLng(sumLat / members.length, sumLng / members.length),
        radiusMeters:
            (250 + 120 * (members.length - 1)).clamp(250, 1600).toDouble(),
        userCount: members.length,
        intensity: (members.length / 6).clamp(0.0, 1.0),
      ),
    );
  }

  return zones;
}
