import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/parking_area.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';
import 'booking_success_screen.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final ParkingArea area;
  final Map<String, dynamic> slot;
  final DateTime startTime;
  final DateTime endTime;
  final double amount;

  const BookingConfirmationScreen({
    super.key,
    required this.area,
    required this.slot,
    required this.startTime,
    required this.endTime,
    required this.amount,
  });

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleController = TextEditingController();
  final _phoneController = TextEditingController();
  final _authService = AuthService();
  late Razorpay _razorpay;
  bool _isProcessing = false;
  int? _bookingId;
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _loadUserData();
  }

  @override
  void dispose() {
    _razorpay.clear();
    _vehicleController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getStoredUser();
      if (user != null && mounted) {
        setState(() {
          _currentUser = user;
          // Pre-fill phone if available
          if (user['phone'] != null &&
              !user['phone'].toString().startsWith('GOOGLE_') &&
              !user['phone'].toString().startsWith('APPLE_')) {
            _phoneController.text = user['phone'];
          }
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _createBookingAndPay() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      // Get user ID from auth service
      final userId = await _authService.getUserId();

      if (userId == null) {
        throw Exception('Please login to continue');
      }

      // Step 1: Create pending booking
      final bookingUrl = Uri.parse('${ApiConfig.baseUrl}/api/bookings');
      final bookingRes = await http.post(
        bookingUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'slotId': widget.slot['id'],
          'userId': userId, // ← Real logged-in user ID
          'startTime': widget.startTime.toIso8601String(),
          'endTime': widget.endTime.toIso8601String(),
          'vehicle_number': _vehicleController.text.trim().toUpperCase(),
          'phone': _phoneController.text.trim(),
        }),
      );

      if (bookingRes.statusCode != 201) {
        final error = jsonDecode(bookingRes.body);
        throw Exception(error['error'] ?? 'Failed to create booking');
      }

      final booking = jsonDecode(bookingRes.body);
      _bookingId = booking['id'];

      print('✅ Booking created: $_bookingId for user: $userId');

      // Step 2: Create Razorpay order
      final orderUrl = Uri.parse(
        '${ApiConfig.baseUrl}/api/bookings/$_bookingId/create-order',
      );
      final orderRes = await http.post(orderUrl);

      if (orderRes.statusCode != 200) {
        final error = jsonDecode(orderRes.body);
        throw Exception(error['error'] ?? 'Failed to create payment order');
      }

      final orderData = jsonDecode(orderRes.body);

      print('✅ Razorpay order created: ${orderData['orderId']}');

      // Step 3: Open Razorpay checkout
      final options = {
        'key': orderData['keyId'],
        'amount': (orderData['amount'] * 100).toInt(),
        'currency': 'INR',
        'name': 'Urb Park',
        'description': 'Parking Slot Booking - ${widget.slot['slotNumber']}',
        'order_id': orderData['orderId'],
        'prefill': {
          'contact': _phoneController.text.trim(),
          'email': _currentUser?['email'] ?? '',
          'name': _currentUser?['name'] ?? '',
        },
        'theme': {
          'color': '#F5C63B',
        },
        'notes': {
          'slot': widget.slot['slotNumber'],
          'parking': widget.area.name,
          'vehicle': _vehicleController.text.trim().toUpperCase(),
        },
      };

      _razorpay.open(options);
    } catch (e) {
      print('❌ Error: $e');
      if (!mounted) return;

      setState(() => _isProcessing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    print('✅ Payment Success: ${response.paymentId}');

    try {
      // Verify payment on backend
      final verifyUrl = Uri.parse(
        '${ApiConfig.baseUrl}/api/bookings/$_bookingId/verify-payment',
      );

      final verifyRes = await http.post(
        verifyUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'razorpayOrderId': response.orderId,
          'razorpayPaymentId': response.paymentId,
          'razorpaySignature': response.signature,
        }),
      );

      if (verifyRes.statusCode != 200) {
        final error = jsonDecode(verifyRes.body);
        throw Exception(error['error'] ?? 'Payment verification failed');
      }

      final confirmedBooking = jsonDecode(verifyRes.body);

      print('✅ Booking confirmed: ${confirmedBooking['id']}');

      if (!mounted) return;

      // Navigate to success screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BookingSuccessScreen(
            booking: confirmedBooking,
          ),
        ),
      );
    } catch (e) {
      print('❌ Verification error: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment verification failed: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('❌ Payment Error: ${response.code} - ${response.message}');

    setState(() => _isProcessing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: ${response.message ?? 'Unknown error'}'),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('🔗 External Wallet: ${response.walletName}');
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.endTime.difference(widget.startTime);
    final hours = (duration.inMinutes / 60).ceil();

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
          'Confirm Booking',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Info Card (if logged in)
              if (_currentUser != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF2D2D33),
                        const Color(0xFF252529),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF3A3A40)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFF5C63B),
                              const Color(0xFFE6B42E),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: _currentUser!['profilePic'] != null
                            ? ClipOval(
                          child: Image.network(
                            _currentUser!['profilePic'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person,
                              color: Color(0xFF1A1A1F),
                            ),
                          ),
                        )
                            : const Icon(
                          Icons.person,
                          color: Color(0xFF1A1A1F),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentUser!['name'] ?? 'User',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              _currentUser!['email'] ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF8D8D93),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4ADE80).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.verified,
                              size: 14,
                              color: Color(0xFF4ADE80),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF4ADE80),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Parking Details Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2D2D33),
                      const Color(0xFF252529),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF3A3A40)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5C63B).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.local_parking,
                            color: Color(0xFFF5C63B),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.area.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                widget.area.city,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF8D8D93),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _infoRow('Slot', widget.slot['slotNumber']),
                    const SizedBox(height: 8),
                    _infoRow(
                      'Date',
                      DateFormat('EEE, MMM d, yyyy').format(widget.startTime),
                    ),
                    const SizedBox(height: 8),
                    _infoRow(
                      'Time',
                      '${DateFormat('hh:mm a').format(widget.startTime)} - ${DateFormat('hh:mm a').format(widget.endTime)}',
                    ),
                    const SizedBox(height: 8),
                    _infoRow('Duration', '$hours ${hours == 1 ? 'hour' : 'hours'}'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Vehicle Details
              const Text(
                'Vehicle Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _vehicleController,
                style: const TextStyle(color: Colors.white),
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Vehicle Number',
                  hintText: 'KA01AB1234',
                  hintStyle: const TextStyle(color: Color(0xFF52525B)),
                  labelStyle: const TextStyle(color: Color(0xFF8D8D93)),
                  prefixIcon: const Icon(Icons.directions_car, color: Color(0xFFF5C63B)),
                  filled: true,
                  fillColor: const Color(0xFF2D2D33),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF3A3A40)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF3A3A40)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFF5C63B)),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Vehicle number is required';
                  if (v.length < 6) return 'Enter valid vehicle number';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '9876543210',
                  hintStyle: const TextStyle(color: Color(0xFF52525B)),
                  labelStyle: const TextStyle(color: Color(0xFF8D8D93)),
                  prefixIcon: const Icon(Icons.phone, color: Color(0xFFF5C63B)),
                  filled: true,
                  fillColor: const Color(0xFF2D2D33),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF3A3A40)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF3A3A40)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFF5C63B)),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Phone number is required';
                  if (v.length != 10) return 'Enter valid 10-digit phone number';
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Price Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5C63B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFF5C63B).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '₹${widget.amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFF5C63B),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Pay Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _createBookingAndPay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5C63B),
                    foregroundColor: const Color(0xFF1A1A1F),
                    disabledBackgroundColor: const Color(0xFF3A3A40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF1A1A1F),
                    ),
                  )
                      : const Text(
                    'Proceed to Pay',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF8D8D93),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
