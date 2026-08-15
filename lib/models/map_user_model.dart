/// Another user shown on the map, with a similarity score (0.0-1.0)
/// describing how close their profile settings are to the current user's.
class MapUserModel {
  const MapUserModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.similarity,
    this.age,
  });

  final String id;
  final String name;
  final int? age;
  final double latitude;
  final double longitude;
  final double similarity;

  factory MapUserModel.fromJson(Map<String, dynamic> json) {
    return MapUserModel(
      id: '${json['id']}',
      name: json['name'] as String? ?? '',
      age: json['age'] as int?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      similarity: ((json['similarity'] as num?)?.toDouble() ?? 0).clamp(0, 1),
    );
  }
}
