import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:urban_parking_app/screens/slot_selection_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/parking_area.dart';
import '../config/api_config.dart';

class ParkingDetailsScreen extends StatefulWidget {
  final ParkingArea area;

  const ParkingDetailsScreen({super.key, required this.area});

  @override
  State<ParkingDetailsScreen> createState() => _ParkingDetailsScreenState();
}

class _ParkingDetailsScreenState extends State<ParkingDetailsScreen> {
  late GoogleMapController _mapController;
  final PageController _photoController = PageController();
  bool _isLoadingDetails = true;
  Map<String, dynamic>? _details;
  List<dynamic> _reviews = [];

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      // Get current time + 1 hour window for availability check
      final now = DateTime.now();
      final oneHourLater = now.add(const Duration(hours: 1));

      // Fetch details
      final detailsUrl = Uri.parse(
        '${ApiConfig.baseUrl}/api/parking-areas/${widget.area.id}/details'
            '?startTime=${now.toIso8601String()}'
            '&endTime=${oneHourLater.toIso8601String()}',
      );

      final reviewsUrl = Uri.parse(
        '${ApiConfig.baseUrl}/api/parking-areas/${widget.area.id}/reviews',
      );

      final responses = await Future.wait([
        http.get(detailsUrl),
        http.get(reviewsUrl),
      ]);

      if (mounted) {
        setState(() {
          _details = jsonDecode(responses[0].body);
          _reviews = jsonDecode(responses[1].body);
          _isLoadingDetails = false;
        });
      }
    } catch (e) {
      print('Error loading details: $e');
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
        });
      }
    }
  }

  Future<void> _launchNavigation() async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${widget.area.lat},${widget.area.long}',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1F),
      body: CustomScrollView(
        slivers: [
          // App Bar with image gallery
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF1A1A1F),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1F).withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Photo Gallery
                  _buildPhotoGallery(),

                  // Gradient overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            const Color(0xFF1A1A1F),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildAvailabilityCard(),
                _buildMap(),
                _buildFeaturesSection(),
                _buildReviewsSection(),
                const SizedBox(height: 100), // Space for bottom button
              ],
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomButton(),
    );
  }

  Widget _buildPhotoGallery() {
    // Mock photos - replace with real images later
    final photos = [
      'https://images.unsplash.com/photo-1590674899484-d5640e854abe?w=800',
      'https://images.unsplash.com/photo-1506521781263-d8422e82f27a?w=800',
      'https://images.unsplash.com/photo-1470224114660-3f6686c562eb?q=80&w=735&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
    ];

    return Stack(
      children: [
        PageView.builder(
          controller: _photoController,
          itemCount: photos.length,
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(photos[index]),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.3),
                    BlendMode.darken,
                  ),
                ),
              ),
            );
          },
        ),

        // Page indicator
        Positioned(
          bottom: 120,
          left: 0,
          right: 0,
          child: Center(
            child: SmoothPageIndicator(
              controller: _photoController,
              count: photos.length,
              effect: WormEffect(
                dotWidth: 8,
                dotHeight: 8,
                activeDotColor: const Color(0xFFF5C63B),
                dotColor: Colors.white.withOpacity(0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.area.name,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFFFFF),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (widget.area.features.contains('Premium'))
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFACC15),
                        const Color(0xFFEAB308),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: Color(0xFF1A1A1F),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'PREMIUM',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A1A1F),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.location_on,
                size: 16,
                color: Color(0xFFF5C63B),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.area.address,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFA1A1AA),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(
                Icons.access_time,
                '24/7 Open',
                const Color(0xFF4ADE80),
              ),
              const SizedBox(width: 12),
              if (widget.area.distance != null)
                _buildInfoChip(
                  Icons.near_me,
                  '${widget.area.distance!.toStringAsFixed(1)} km',
                  const Color(0xFF38BDF8),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard() {
    if (_isLoadingDetails) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D33),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF3A3A40)),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFF5C63B),
          ),
        ),
      );
    }

    final available = _details?['availableSlots'] ?? widget.area.totalSlots;
    final total = widget.area.totalSlots;
    final occupancy = _details?['occupancyRate'] ?? '0';
    final isAvailable = available > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2D2D33),
            const Color(0xFF252529),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAvailable
              ? const Color(0xFF4ADE80).withOpacity(0.3)
              : const Color(0xFFEF4444).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? const Color(0xFF4ADE80).withOpacity(0.15)
                      : const Color(0xFFEF4444).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAvailable ? Icons.check_circle : Icons.cancel,
                  color: isAvailable
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFFEF4444),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAvailable
                          ? '$available Slots Available'
                          : 'Fully Occupied',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Out of $total total slots',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8D8D93),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    '$occupancy%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: isAvailable
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                  const Text(
                    'Occupied',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8D8D93),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Occupancy bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: double.parse(occupancy) / 100,
              backgroundColor: const Color(0xFF3A3A40),
              valueColor: AlwaysStoppedAnimation<Color>(
                isAvailable
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFFEF4444),
              ),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3A3A40)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.area.lat, widget.area.long),
              zoom: 15,
            ),
            markers: {
              Marker(
                markerId: MarkerId(widget.area.id.toString()),
                position: LatLng(widget.area.lat, widget.area.long),
                infoWindow: InfoWindow(title: widget.area.name),
              ),
            },
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: Material(
              color: const Color(0xFFF5C63B),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _launchNavigation,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.directions,
                        size: 18,
                        color: Color(0xFF1A1A1F),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Navigate',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1F),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Amenities & Features',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFFFFFF),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: widget.area.features.map((feature) {
              return _buildFeatureItem(feature);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String feature) {
    IconData icon;
    Color color;

    switch (feature) {
      case 'EV Charging':
        icon = Icons.ev_station;
        color = const Color(0xFF4ADE80);
        break;
      case 'CCTV':
        icon = Icons.videocam_rounded;
        color = const Color(0xFFEF4444);
        break;
      case 'Covered':
        icon = Icons.roofing_rounded;
        color = const Color(0xFF38BDF8);
        break;
      case 'Valet':
      case 'Valet Parking':
        icon = Icons.local_taxi_rounded;
        color = const Color(0xFFF59E0B);
        break;
      case 'Security':
        icon = Icons.security;
        color = const Color(0xFF8B5CF6);
        break;
      case '24x7':
        icon = Icons.access_time;
        color = const Color(0xFF10B981);
        break;
      default:
        icon = Icons.check_circle;
        color = const Color(0xFF6B7280);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            feature,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    if (_reviews.isEmpty) return const SizedBox();

    final avgRating = _reviews.fold<double>(
      0,
          (sum, review) => sum + (review['rating'] as int),
    ) /
        _reviews.length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Reviews',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFFFFFF),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFACC15).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star,
                      size: 16,
                      color: Color(0xFFFACC15),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFACC15),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._reviews.take(3).map((review) => _buildReviewItem(review)),
        ],
      ),
    );
  }

  Widget _buildReviewItem(dynamic review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D33),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3A3A40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFF5C63B),
                child: Text(
                  review['userName'][0].toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1F),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['userName'],
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                    Text(
                      review['date'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8D8D93),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                      (index) => Icon(
                    index < review['rating']
                        ? Icons.star
                        : Icons.star_border,
                    size: 14,
                    color: const Color(0xFFFACC15),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review['comment'],
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFA1A1AA),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1F),
        border: Border(
          top: BorderSide(color: const Color(0xFF3A3A40)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Starting from',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8D8D93),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      '₹',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF5C63B),
                      ),
                    ),
                    Text(
                      widget.area.pricePerHour.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFF5C63B),
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        '/hour',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8D8D93),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFF5C63B),
                      const Color(0xFFE6B42E),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF5C63B).withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    // In _buildBottomButton() method, update the onTap:
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SlotSelectionScreen(area: widget.area),
                        ),
                      );
                    },

                    borderRadius: BorderRadius.circular(16),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'Select Slot',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A1F),
                              letterSpacing: 0.3,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                            color: Color(0xFF1A1A1F),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }
}
