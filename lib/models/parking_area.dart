class ParkingArea {
  final int id;
  final String city;
  final String name;
  final String address;
  final double lat;
  final double long;
  final int totalSlots;
  final double pricePerHour;
  final List<String> features;
  double? distance; // Add this field

  ParkingArea({
    required this.id,
    required this.city,
    required this.name,
    required this.address,
    required this.lat,
    required this.long,
    required this.totalSlots,
    required this.pricePerHour,
    required this.features,
    this.distance, // Add this
  });

  factory ParkingArea.fromJson(Map<String, dynamic> json) {
    return ParkingArea(
      id: json['id'] as int,
      city: json['city'] as String,
      name: json['name'] as String,
      address: json['address'] as String? ?? '',
      lat: (json['lat'] as num).toDouble(),
      long: (json['long'] as num).toDouble(),
      totalSlots: json['totalSlots'] as int,
      pricePerHour: (json['price_per_hour'] as num).toDouble(),
      features: (json['features'] as List<dynamic>).cast<String>(),
    );
  }
}
