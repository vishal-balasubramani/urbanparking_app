import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/parking_area.dart';
import 'package:urban_parking_app/config/api_config.dart';

class ParkingService {
  final http.Client _client;

  ParkingService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<String>> getCities() async {
    final url = '${ApiConfig.baseUrl}/api/cities';
    print('🌐 Fetching cities from: $url'); // DEBUG

    try {
      final res = await _client.get(Uri.parse(url));
      print('📡 Cities response status: ${res.statusCode}'); // DEBUG
      print('📄 Cities response body: ${res.body}'); // DEBUG

      if (res.statusCode != 200) {
        throw Exception('Failed to load cities: ${res.statusCode}');
      }
      final List decoded = jsonDecode(res.body);
      return decoded.cast<String>();
    } catch (e) {
      print('❌ Cities error: $e'); // DEBUG
      rethrow;
    }
  }

  Future<List<ParkingArea>> getParkingAreas({String? city}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/parking-areas').replace(
      queryParameters: city != null && city != 'All' ? {'city': city} : null,
    );

    print('🌐 Fetching parking areas from: $uri'); // DEBUG

    try {
      final res = await _client.get(uri);
      print('📡 Parking areas response status: ${res.statusCode}'); // DEBUG
      print('📄 Parking areas response body: ${res.body.substring(0, 200)}...'); // DEBUG (first 200 chars)

      if (res.statusCode != 200) {
        throw Exception('Failed to load parking areas: ${res.statusCode}');
      }
      final List decoded = jsonDecode(res.body);
      print('✅ Parsed ${decoded.length} parking areas'); // DEBUG

      return decoded.map((e) => ParkingArea.fromJson(e)).toList();
    } catch (e) {
      print('❌ Parking areas error: $e'); // DEBUG
      rethrow;
    }
  }
}
