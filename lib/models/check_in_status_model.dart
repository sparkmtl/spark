class CheckInStatusModel {
  const CheckInStatusModel({
    required this.checkedIn,
    this.anchorLatitude,
    this.anchorLongitude,
    this.latitude,
    this.longitude,
  });

  final bool checkedIn;
  final double? anchorLatitude;
  final double? anchorLongitude;
  final double? latitude;
  final double? longitude;

  factory CheckInStatusModel.fromJson(Map<String, dynamic> json) {
    return CheckInStatusModel(
      checkedIn: json['checkedIn'] as bool? ?? false,
      anchorLatitude: (json['anchorLatitude'] as num?)?.toDouble(),
      anchorLongitude: (json['anchorLongitude'] as num?)?.toDouble(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}
