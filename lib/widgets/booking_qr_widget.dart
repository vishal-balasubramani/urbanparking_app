import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import '../config/api_config.dart';

class BookingQRWidget extends StatefulWidget {
  final int bookingId;
  final bool autoRefresh;

  const BookingQRWidget({
    super.key,
    required this.bookingId,
    this.autoRefresh = true,
  });

  @override
  State<BookingQRWidget> createState() => _BookingQRWidgetState();
}

class _BookingQRWidgetState extends State<BookingQRWidget> {
  Timer? _timer;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _qrData;
  bool _showQR = false;
  String _qrStatus = 'INACTIVE';
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _checkQRStatus();

    // Refresh every 5 seconds if autoRefresh is enabled
    if (widget.autoRefresh) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted) _checkQRStatus();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkQRStatus() async {
    try {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/api/bookings/${widget.bookingId}/qr-status',
      );

      final res = await http.get(url);

      if (res.statusCode != 200) {
        throw Exception('Failed to check QR status');
      }

      final data = jsonDecode(res.body);

      if (!mounted) return;

      setState(() {
        _showQR = data['showQR'];
        _qrStatus = data['qrStatus'];
        _statusMessage = data['statusMessage'];
        _qrData = data['booking'];
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor() {
    switch (_qrStatus) {
      case 'ACTIVE':
        return const Color(0xFF4ADE80);
      case 'CANCELLED':
        return const Color(0xFFEF4444);
      case 'EXPIRED':
        return const Color(0xFF9CA3AF);
      case 'COMPLETED':
        return const Color(0xFF3B82F6);
      case 'UPCOMING':
        return const Color(0xFFFACC15);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  IconData _getStatusIcon() {
    switch (_qrStatus) {
      case 'ACTIVE':
        return Icons.qr_code_scanner;
      case 'CANCELLED':
        return Icons.cancel;
      case 'EXPIRED':
        return Icons.access_time;
      case 'COMPLETED':
        return Icons.check_circle;
      case 'UPCOMING':
        return Icons.schedule;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFACC15)),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
            const SizedBox(height: 12),
            Text(
              'Failed to load QR',
              style: const TextStyle(color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _checkQRStatus,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // QR Code or Status Message
        if (_showQR) ...[
          // Active QR Code
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: jsonEncode({
                'bookingId': _qrData!['id'],
                'slot': _qrData!['slot']['slotNumber'],
                'parking': _qrData!['slot']['parkingArea']['name'],
                'start': _qrData!['startTime'],
                'end': _qrData!['endTime'],
              }),
              version: QrVersions.auto,
              size: 200,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _getStatusColor()),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getStatusIcon(), size: 20, color: _getStatusColor()),
                const SizedBox(width: 8),
                Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // Status Message when QR is not shown
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _getStatusColor().withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Icon(_getStatusIcon(), size: 64, color: _getStatusColor()),
                const SizedBox(height: 16),
                Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_qrStatus == 'CANCELLED' && _qrData!['refundAmount'] != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ADE80).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF4ADE80)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Refund Initiated',
                          style: TextStyle(
                            color: Color(0xFF4ADE80),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${(_qrData!['refundAmount'] as num).toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Color(0xFF4ADE80),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Estimated: 5-7 business days',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
