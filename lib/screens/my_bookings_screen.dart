import 'dart:async';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../config/api_config.dart';

class MyBookingsScreen extends StatefulWidget {
  final int userId; // logged-in user's id

  const MyBookingsScreen({super.key, required this.userId});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  List<dynamic> _bookings = [];
  Timer? _timer;

  Razorpay? _razorpay;
  Map<String, dynamic>? _pendingExtension; // bookingId, extraMinutes, orderId

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBookings();

    // Refresh countdown / QR every second
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onExtensionPaymentSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _onExtensionPaymentError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay?.clear();
    _timer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/api/users/${widget.userId}/bookings',
      );
      final res = await http.get(url);

      if (res.statusCode != 200) {
        throw Exception('Failed to load bookings: ${res.statusCode}');
      }

      final decoded = jsonDecode(res.body) as List;
      if (!mounted) return;

      setState(() {
        _bookings = decoded;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<dynamic> _filterBookings(String type) {
    final now = DateTime.now();

    return _bookings.where((b) {
      try {
        final start = DateTime.parse(b['startTime']).toLocal();
        final end = DateTime.parse(b['endTime']).toLocal();
        final status = b['bookingStatus'] as String;

        if (type == 'active') {
          return status == 'CONFIRMED' &&
              now.isAfter(start) &&
              now.isBefore(end);
        } else if (type == 'upcoming') {
          return (status == 'CONFIRMED' || status == 'PENDING') &&
              start.isAfter(now);
        } else {
          return end.isBefore(now) ||
              status == 'CANCELLED' ||
              status == 'EXPIRED' ||
              status == 'COMPLETED';
        }
      } catch (_) {
        return false;
      }
    }).toList()
      ..sort((a, b) {
        try {
          final at = DateTime.parse(a['startTime']);
          final bt = DateTime.parse(b['startTime']);
          return type == 'past' ? bt.compareTo(at) : at.compareTo(bt);
        } catch (_) {
          return 0;
        }
      });
  }

  String _formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('EEE, d MMM  hh:mm a').format(dt);
    } catch (_) {
      return iso;
    }
  }

  Duration _remainingForBooking(Map<String, dynamic> booking) {
    final end = DateTime.parse(booking['endTime']).toLocal();
    final now = DateTime.now();
    return end.difference(now);
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return 'Expired';
    final days = d.inDays;
    final h = d.inHours % 24;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (days > 0) return '${days}d ${h}h';
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'CONFIRMED':
        return const Color(0xFF4ADE80);
      case 'PENDING':
        return const Color(0xFFFACC15);
      case 'CANCELLED':
      case 'EXPIRED':
        return const Color(0xFFEF4444);
      case 'COMPLETED':
        return const Color(0xFF9CA3AF);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  bool _shouldShowQR(Map<String, dynamic> booking) {
    try {
      final now = DateTime.now();
      final start = DateTime.parse(booking['startTime']).toLocal();
      final end = DateTime.parse(booking['endTime']).toLocal();
      final status = booking['bookingStatus'] as String;
      return status == 'CONFIRMED' && now.isAfter(start) && now.isBefore(end);
    } catch (_) {
      return false;
    }
  }

  Future<void> _cancelBooking(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cancel Booking?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You will receive a refund based on our cancellation policy.\n\n'
              'Refund will be processed in 5-7 business days.',
          style: TextStyle(color: Color(0xFF9CA3AF)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Cancel & Refund'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFACC15)),
        ),
      );

      final url = Uri.parse('${ApiConfig.baseUrl}/api/bookings/$id/cancel');
      final res = await http.post(url);

      if (!mounted) return;
      Navigator.pop(context);

      if (res.statusCode != 200) {
        Map<String, dynamic>? data;
        try {
          data = jsonDecode(res.body);
        } catch (_) {}
        throw Exception(data?['error'] ?? 'Failed to cancel booking');
      }

      final data = jsonDecode(res.body);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF18181B),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF4ADE80), size: 32),
              SizedBox(width: 12),
              Text(
                'Booking Cancelled',
                style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            data['message'] ?? 'Booking cancelled successfully',
            style: const TextStyle(color: Color(0xFF9CA3AF)),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _loadBookings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFACC15),
                foregroundColor: const Color(0xFF111827),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling booking: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  // ---------- EXTENSION: Razorpay handlers ----------

  void _onExtensionPaymentSuccess(PaymentSuccessResponse response) async {
    if (_pendingExtension == null) return;
    final bookingId = _pendingExtension!['bookingId'] as int;
    final extraMinutes = _pendingExtension!['extraMinutes'] as int;
    final orderId = _pendingExtension!['orderId'] as String;

    try {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/api/bookings/$bookingId/confirm-extension',
      );
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'extraMinutes': extraMinutes,
          'razorpayPaymentId': response.paymentId,
          'razorpayOrderId': orderId,
          'razorpaySignature': response.signature,
        }),
      );

      if (res.statusCode != 200) {
        throw Exception('Failed to confirm extension (${res.statusCode})');
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        throw Exception('Server returned invalid JSON for confirm-extension.');
      }

      final updatedBooking = data['booking'];
      if (updatedBooking == null) {
        throw Exception('No booking field in confirm-extension response.');
      }

      if (!mounted) return;

      // âœ… CRITICAL FIX: Reload ALL bookings from backend to get fresh endTime
      await _loadBookings();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking extended successfully'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error confirming extension: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      _pendingExtension = null;
    }
  }

  void _onExtensionPaymentError(PaymentFailureResponse response) {
    _pendingExtension = null;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Extension payment failed: ${response.message}'),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    // optional
  }

  Future<void> _extendBooking(Map<String, dynamic> booking) async {
    final options = [30, 60, 90];

    final extraMinutes = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Extend Session',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map(
                (m) => ListTile(
              title: Text(
                '+ $m minutes',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, m),
            ),
          )
              .toList(),
        ),
      ),
    );

    if (extraMinutes == null) return;

    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFACC15)),
        ),
      );

      // 1) Ask backend to create extension order
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/api/bookings/${booking['id']}/create-extension-order',
      );
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'extraMinutes': extraMinutes}),
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (res.statusCode != 200) {
        // Do not jsonDecode HTML error pages
        throw Exception(
            'Failed to create extension order (${res.statusCode})');
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        throw Exception('Server returned invalid JSON for extension order.');
      }

      final orderId = data['orderId'];
      final amount = data['amount']; // INR
      final keyId = data['keyId'];

      if (orderId == null || amount == null || keyId == null) {
        throw Exception('Missing fields in extension order response.');
      }

      // 2) Open Razorpay
      _pendingExtension = {
        'bookingId': booking['id'],
        'extraMinutes': extraMinutes,
        'orderId': orderId,
      };

      final optionsRzp = {
        'key': keyId,
        'amount': (amount * 100).toInt(), // in paise
        'currency': 'INR',
        'name': 'Urb Park',
        'description': 'Extend Parking Session',
        'order_id': orderId,
        'prefill': {
          'contact': booking['phone'] ?? '',
          'email': '', // fill from profile if available
        },
        'notes': {
          'bookingId': booking['id'].toString(),
          'extraMinutes': extraMinutes.toString(),
        },
        'theme': {'color': '#FACC15'},
      };

      _razorpay?.open(optionsRzp);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error extending booking: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _navigateToParking(Map<String, dynamic> booking) async {
    final area = booking['slot']['parkingArea'];
    final lat = area['lat'] as double;
    final lng = area['long'] as double;
    final name = area['name'] as String;

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Navigate to Parking',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.map, color: Color(0xFFFACC15)),
              title: const Text('View on Map', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'view'),
            ),
            ListTile(
              leading: const Icon(Icons.navigation, color: Color(0xFF38BDF8)),
              title: const Text('Start Navigation', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'navigate'),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    final Uri googleMapsUrl;

    if (choice == 'navigate') {
      // Turn-by-turn navigation
      googleMapsUrl = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving'
      );
    } else {
      // View location
      googleMapsUrl = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng'
      );
    }

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not open Google Maps';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening maps: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B10),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Bookings',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadBookings,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFACC15),
          unselectedLabelColor: const Color(0xFF6B7280),
          indicatorColor: const Color(0xFFFACC15),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFFFACC15)),
      )
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              const Text(
                'Failed to load bookings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadBookings,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFACC15),
                  foregroundColor: const Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      )
          : TabBarView(
        controller: _tabController,
        children: [
          _buildBookingsList('active'),
          _buildBookingsList('upcoming'),
          _buildBookingsList('past'),
        ],
      ),
    );
  }

  Widget _buildBookingsList(String type) {
    final list = _filterBookings(type);

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today,
                size: 52, color: Color(0xFF4B5563)),
            const SizedBox(height: 12),
            Text(
              type == 'active'
                  ? 'No active bookings'
                  : type == 'upcoming'
                  ? 'No upcoming bookings'
                  : 'No past bookings',
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final booking = list[index];
        return _buildBookingCard(booking, type);
      },
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking, String type) {
    if (booking['slot'] == null || booking['slot']['parkingArea'] == null) {
      return const SizedBox.shrink();
    }

    final area = booking['slot']['parkingArea'];
    final status = booking['bookingStatus'] as String;
    final showQR = _shouldShowQR(booking);

    Duration displayDuration;
    if (type == 'active') {
      displayDuration = _remainingForBooking(booking);
    } else if (type == 'upcoming') {
      final start = DateTime.parse(booking['startTime']).toLocal();
      final now = DateTime.now();
      displayDuration = start.difference(now);
    } else {
      displayDuration = const Duration(seconds: -1);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF020617)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: showQR
              ? const Color(0xFF22C55E).withOpacity(0.6)
              : const Color(0xFF1F2937),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showQR) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: jsonEncode({
                      'bookingId': booking['id'],
                      'slot': booking['slot']['slotNumber'],
                      'parking': area['name'],
                      'start': booking['startTime'],
                      'end': booking['endTime'],
                      'vehicle': booking['vehicle_number'],
                    }),
                    version: QrVersions.auto,
                    size: 180,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFF22C55E)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.qr_code_scanner,
                            size: 16, color: Color(0xFF22C55E)),
                        const SizedBox(width: 6),
                        Text(
                          booking['entryScanned'] == true
                              ? 'Vehicle Inside'
                              : 'Scan at Entry Gate',
                          style: const TextStyle(
                            color: Color(0xFF22C55E),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFACC15).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.local_parking,
                        color: Color(0xFFFACC15),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            area['name'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _formatDateTime(booking['startTime']),
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: _statusColor(status),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.pin_drop_rounded,
                        size: 16, color: Color(0xFFFACC15)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        area['address'] ?? area['city'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _chip(
                      icon: Icons.local_parking,
                      label: booking['slot']['slotNumber'],
                      color: const Color(0xFF38BDF8),
                    ),
                    const SizedBox(width: 8),
                    if (type == 'active' || type == 'upcoming')
                      _chip(
                        icon: Icons.timer,
                        label: type == 'active'
                            ? 'Ends ${_formatDuration(displayDuration)}'
                            : 'Starts ${_formatDuration(displayDuration)}',
                        color: const Color(0xFFF97316),
                      ),
                    const Spacer(),
                    Text(
                      '₹${(booking['amount'] as num).toInt()}',
                      style: const TextStyle(
                        color: Color(0xFFFACC15),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _navigateToParking(booking),
                      icon: const Icon(Icons.navigation, size: 16),
                      label: const Text(
                        'Navigate',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFACC15),
                      ),
                    ),
                    const Spacer(),
                    if (type == 'active')
                      TextButton(
                        onPressed: () => _extendBooking(booking),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF38BDF8),
                        ),
                        child: const Text(
                          'Extend',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    if (type == 'active' || type == 'upcoming')
                      TextButton(
                        onPressed: () => _cancelBooking(booking['id']),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}