import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/parking_area.dart';
import '../services/parking_service.dart';
import '../services/location_service.dart';
import 'parking_details_screen.dart';
import 'my_bookings_screen.dart'; // ← ADD THIS

class ParkingListScreen extends StatefulWidget {
  const ParkingListScreen({super.key});

  @override
  State<ParkingListScreen> createState() => _ParkingListScreenState();
}

class _ParkingListScreenState extends State<ParkingListScreen> {
  final ParkingService _service = ParkingService();
  List<ParkingArea> _areas = [];
  bool _isLoading = true;
  String? _error;
  String _selectedCity = 'All';
  List<String> _cities = ['All'];
  Position? _userLocation;
  bool _sortByDistance = false;

  @override
  void initState() {
    super.initState();
    print('🚀 ParkingListScreen initialized');
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _userLocation = await LocationService.getCurrentLocation();

      print('📡 Loading cities...');
      final cities = await _service.getCities();
      print('✅ Got ${cities.length} cities: $cities');

      print('📡 Loading parking areas...');
      final areas = await _service.getParkingAreas();
      print('✅ Got ${areas.length} parking areas');

      if (_userLocation != null) {
        for (var area in areas) {
          area.distance = LocationService.calculateDistance(
            _userLocation!.latitude,
            _userLocation!.longitude,
            area.lat,
            area.long,
          );
        }
        print('✅ Calculated distances from user location');
      }

      if (mounted) {
        setState(() {
          _cities = ['All', 'Nearby', ...cities];
          _areas = areas;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('❌ Error loading data: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onCityChanged(String city) {
    setState(() {
      _selectedCity = city;
      _sortByDistance = city == 'Nearby';
    });
  }

  List<ParkingArea> _getFilteredAreas() {
    var filtered = _areas;

    if (_selectedCity != 'All' && _selectedCity != 'Nearby') {
      filtered = filtered.where((a) => a.city == _selectedCity).toList();
    }

    if (_sortByDistance && _userLocation != null) {
      filtered = List.from(filtered)
        ..sort((a, b) {
          if (a.distance == null) return 1;
          if (b.distance == null) return -1;
          return a.distance!.compareTo(b.distance!);
        });
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Find Parking',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFFFFFFFF),
          ),
        ),
        actions: [
          // ← ADD THIS: My Bookings Button
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.receipt_long, size: 24),
                // Optional: Add notification badge
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF1A1A1F),
                        width: 1.5,
                      ),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 8,
                      minHeight: 8,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MyBookingsScreen(userId: 1), // Use actual userId when auth is ready
                ),
              );
            },
            tooltip: 'My Bookings',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCityChips(),
          const SizedBox(height: 8),

          if (_userLocation != null && _sortByDistance)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2D33),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3A3A40)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ADE80).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.my_location,
                      size: 16,
                      color: Color(0xFF4ADE80),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Showing parking areas sorted by distance from you',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFA1A1AA),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFFF5C63B),
            ),
            SizedBox(height: 16),
            Text(
              'Loading parking areas...',
              style: TextStyle(
                color: Color(0xFFA1A1AA),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 60,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(height: 16),
              const Text(
                'Failed to load',
                style: TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFA1A1AA),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5C63B),
                  foregroundColor: const Color(0xFF1A1A1F),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filteredAreas = _getFilteredAreas();

    if (filteredAreas.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_parking,
              size: 60,
              color: Color(0xFF8D8D93),
            ),
            SizedBox(height: 16),
            Text(
              'No parking areas found',
              style: TextStyle(
                color: Color(0xFFA1A1AA),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filteredAreas.length,
      itemBuilder: (context, index) {
        return ParkingCard(
          area: filteredAreas[index],
          showDistance: _sortByDistance && _userLocation != null,
        );
      },
    );
  }

  Widget _buildCityChips() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _cities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = _cities[index];
          final selected = label == _selectedCity;
          final isNearby = label == 'Nearby';

          return GestureDetector(
            onTap: () => _onCityChanged(label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFF5C63B)
                    : const Color(0xFF2D2D33),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFF5C63B)
                      : const Color(0xFF3A3A40),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isNearby)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.near_me,
                        size: 14,
                        color: selected
                            ? const Color(0xFF1A1A1F)
                            : const Color(0xFFF5C63B),
                      ),
                    ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? const Color(0xFF1A1A1F)
                          : const Color(0xFFE4E4E7),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ParkingCard widget remains the same...
class ParkingCard extends StatelessWidget {
  final ParkingArea area;
  final bool showDistance;

  const ParkingCard({
    super.key,
    required this.area,
    this.showDistance = false,
  });

  @override
  Widget build(BuildContext context) {
    final price = area.pricePerHour.toStringAsFixed(0);
    final hasEV = area.features.contains('EV Charging');
    final isAirport = area.features.contains('Airport');
    final isPremium = area.features.contains('Premium');
    final isCovered = area.features.contains('Covered');
    final isMall = area.features.contains('Mall Parking');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2A2A30),
            const Color(0xFF1F1F24),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPremium
              ? const Color(0xFFF5C63B).withOpacity(0.3)
              : const Color(0xFF3A3A40),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isPremium
                ? const Color(0xFFF5C63B).withOpacity(0.15)
                : Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: isPremium ? 1 : 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ParkingDetailsScreen(area: area),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    // Icon
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFF5C63B),
                            const Color(0xFFE6B42E),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF5C63B).withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        isAirport
                            ? Icons.local_airport_rounded
                            : isMall
                            ? Icons.shopping_bag_rounded
                            : Icons.local_parking_rounded,
                        color: const Color(0xFF1A1A1F),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Name and location
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            area.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFFFFFF),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                showDistance ? Icons.near_me : Icons.location_on,
                                size: 14,
                                color: const Color(0xFFF5C63B),
                              ),
                              const SizedBox(width: 4),
                              if (showDistance && area.distance != null)
                                Text(
                                  '${area.distance!.toStringAsFixed(1)} km away',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFF5C63B),
                                  ),
                                )
                              else
                                Text(
                                  area.city,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFF5C63B),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Premium badge
                    if (isPremium)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFACC15),
                              const Color(0xFFEAB308),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.star_rounded,
                              size: 12,
                              color: Color(0xFF1A1A1F),
                            ),
                            SizedBox(width: 3),
                            Text(
                              'PRO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1A1A1F),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Features
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (hasEV)
                      _featureChip('EV', Icons.ev_station, const Color(0xFF4ADE80)),
                    if (isCovered)
                      _featureChip('Covered', Icons.roofing_rounded, const Color(0xFF38BDF8)),
                    _featureChip('${area.totalSlots} Slots', Icons.grid_view_rounded, const Color(0xFF8B5CF6)),
                  ],
                ),

                const SizedBox(height: 16),

                // Bottom row
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2D33),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF3A3A40)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  '₹',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFF5C63B),
                                  ),
                                ),
                                Text(
                                  price,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFF5C63B),
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '/hour',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF8D8D93),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Button
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFF5C63B),
                              const Color(0xFFE6B42E),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF5C63B).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ParkingDetailsScreen(area: area),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text(
                                    'View',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1A1A1F),
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 18,
                                    color: Color(0xFF1A1A1F),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
