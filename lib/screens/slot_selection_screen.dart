import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/parking_area.dart';
import '../config/api_config.dart';
import 'booking_confirmation_screen.dart';

class SlotSelectionScreen extends StatefulWidget {
  final ParkingArea area;

  const SlotSelectionScreen({super.key, required this.area});

  @override
  State<SlotSelectionScreen> createState() => _SlotSelectionScreenState();
}

class _SlotSelectionScreenState extends State<SlotSelectionScreen> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay(hour: TimeOfDay.now().hour + 2, minute: 0);

  List<dynamic> _availableSlots = [];
  bool _isLoadingSlots = false;
  Map<String, dynamic>? _autoSelectedSlot;

  @override
  void initState() {
    super.initState();
    _loadAvailableSlots();
  }

  Future<void> _loadAvailableSlots() async {
    setState(() {
      _isLoadingSlots = true;
      _autoSelectedSlot = null;
    });

    try {
      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      final endDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      final url = Uri.parse(
        '${ApiConfig.baseUrl}/api/parking-areas/${widget.area.id}/slots-status'
            '?startTime=${startDateTime.toIso8601String()}'
            '&endTime=${endDateTime.toIso8601String()}',
      );

      print('🔍 Fetching slots: $url');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final allSlots = jsonDecode(response.body) as List;
        print('✅ Got ${allSlots.length} total slots');

        // Filter only available slots
        final available = allSlots.where((slot) => slot['status'] == 'AVAILABLE').toList();

        print('✅ Found ${available.length} available slots');

        if (mounted) {
          setState(() {
            _availableSlots = available;
            // Auto-select the first available slot
            if (available.isNotEmpty) {
              _autoSelectedSlot = available[0];
            }
            _isLoadingSlots = false;
          });
        }
      } else {
        throw Exception('Failed to load slots');
      }
    } catch (e) {
      print('❌ Error loading slots: $e');
      if (mounted) {
        setState(() {
          _isLoadingSlots = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading slots: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFF5C63B),
              onPrimary: Color(0xFF1A1A1F),
              surface: Color(0xFF2D2D33),
              onSurface: Color(0xFFFFFFFF),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadAvailableSlots();
    }
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFF5C63B),
              onPrimary: Color(0xFF1A1A1F),
              surface: Color(0xFF2D2D33),
              onSurface: Color(0xFFFFFFFF),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _startTime) {
      setState(() {
        _startTime = picked;
        final startMinutes = picked.hour * 60 + picked.minute;
        final endMinutes = _endTime.hour * 60 + _endTime.minute;
        if (endMinutes <= startMinutes) {
          _endTime = TimeOfDay(
            hour: (picked.hour + 2) % 24,
            minute: picked.minute,
          );
        }
      });
      _loadAvailableSlots();
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFF5C63B),
              onPrimary: Color(0xFF1A1A1F),
              surface: Color(0xFF2D2D33),
              onSurface: Color(0xFFFFFFFF),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _endTime) {
      final startMinutes = _startTime.hour * 60 + _startTime.minute;
      final endMinutes = picked.hour * 60 + picked.minute;

      if (endMinutes <= startMinutes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End time must be after start time'),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      setState(() {
        _endTime = picked;
      });
      _loadAvailableSlots();
    }
  }

  double _calculatePrice() {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    final durationMinutes = endMinutes - startMinutes;
    final hours = (durationMinutes / 60).ceil();
    return hours * widget.area.pricePerHour;
  }

  String _getDuration() {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    final durationMinutes = endMinutes - startMinutes;
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;

    if (minutes == 0) {
      return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    }
    return '$hours hr $minutes min';
  }

  void _proceedToBooking() {
    if (_autoSelectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No slots available for selected time'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingConfirmationScreen(
          area: widget.area,
          slot: _autoSelectedSlot!,
          startTime: DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            _startTime.hour,
            _startTime.minute,
          ),
          endTime: DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            _endTime.hour,
            _endTime.minute,
          ),
          amount: _calculatePrice(),
        ),
      ),
    );
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Book Parking',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              widget.area.name,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFA1A1AA),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: _isLoadingSlots
          ? const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFF5C63B),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date & Time Selector
            _buildDateTimeSelector(),

            const SizedBox(height: 24),

            // Availability Status
            _buildAvailabilityCard(),

            const SizedBox(height: 24),

            // Auto-selected Slot Display
            if (_autoSelectedSlot != null) _buildSelectedSlotCard(),

            const SizedBox(height: 24),

            // Proceed Button
            _buildProceedButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeSelector() {
    return Container(
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5C63B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.schedule,
                  color: Color(0xFFF5C63B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Select Date & Time',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFFFFFF),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Date Selector
          GestureDetector(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5C63B).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: Color(0xFFF5C63B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Date',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8D8D93),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('EEE, MMM d, yyyy').format(_selectedDate),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Color(0xFF8D8D93),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Time Range
          Row(
            children: [
              // Start Time
              Expanded(
                child: GestureDetector(
                  onTap: _selectStartTime,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3A40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4ADE80).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.login,
                            size: 18,
                            color: Color(0xFF4ADE80),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Start',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF8D8D93),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _startTime.format(context),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFFFFFF),
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

              const SizedBox(width: 12),

              // End Time
              Expanded(
                child: GestureDetector(
                  onTap: _selectEndTime,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3A40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.logout,
                            size: 18,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'End',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF8D8D93),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _endTime.format(context),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFFFFFF),
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
            ],
          ),

          const SizedBox(height: 12),

          // Duration & Price
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5C63B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFF5C63B).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 16,
                      color: Color(0xFFF5C63B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getDuration(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF5C63B),
                      ),
                    ),
                  ],
                ),
                Text(
                  '₹${_calculatePrice().toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFF5C63B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard() {
    final totalSlots = widget.area.totalSlots;
    final availableCount = _availableSlots.length;
    final occupancyRate = ((totalSlots - availableCount) / totalSlots * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: availableCount > 0
              ? [
            const Color(0xFF4ADE80).withOpacity(0.15),
            const Color(0xFF22C55E).withOpacity(0.05),
          ]
              : [
            const Color(0xFFEF4444).withOpacity(0.15),
            const Color(0xFFDC2626).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: availableCount > 0
              ? const Color(0xFF4ADE80).withOpacity(0.3)
              : const Color(0xFFEF4444).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    availableCount > 0 ? 'Slots Available' : 'Fully Booked',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: availableCount > 0
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    availableCount > 0
                        ? '$availableCount out of $totalSlots slots free'
                        : 'No slots available for this time',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFA1A1AA),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: availableCount > 0
                      ? const Color(0xFF4ADE80).withOpacity(0.2)
                      : const Color(0xFFEF4444).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  availableCount > 0 ? Icons.check_circle : Icons.block,
                  color: availableCount > 0
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFFEF4444),
                  size: 32,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Occupancy bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A40),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (totalSlots - availableCount) / totalSlots,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: availableCount > totalSlots * 0.3
                        ? [const Color(0xFF4ADE80), const Color(0xFF22C55E)]
                        : [const Color(0xFFEF4444), const Color(0xFFDC2626)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$occupancyRate% occupied',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8D8D93),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (availableCount > 0)
                Text(
                  '${(availableCount / totalSlots * 100).toStringAsFixed(0)}% available',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4ADE80),
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedSlotCard() {
    final slotNumber = _autoSelectedSlot!['slotNumber'] as String;
    final slotType = _autoSelectedSlot!['type'] as String;

    IconData slotIcon = Icons.local_parking;
    Color iconColor = const Color(0xFFF5C63B);

    if (slotType == 'EV') {
      slotIcon = Icons.ev_station;
      iconColor = const Color(0xFF4ADE80);
    } else if (slotType == 'DISABLED') {
      slotIcon = Icons.accessible;
      iconColor = const Color(0xFF38BDF8);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF5C63B).withOpacity(0.15),
            const Color(0xFFE6B42E).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF5C63B).withOpacity(0.4),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              slotIcon,
              color: iconColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Auto-Assigned Slot',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8D8D93),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ADE80).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'AVAILABLE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4ADE80),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  slotNumber,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFF5C63B),
                    height: 1.2,
                  ),
                ),
                if (slotType != 'REGULAR') ...[
                  const SizedBox(height: 4),
                  Text(
                    slotType == 'EV' ? '⚡ EV Charging Available' : '♿ Disabled Parking',
                    style: TextStyle(
                      fontSize: 12,
                      color: iconColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4ADE80).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.check_circle,
              color: Color(0xFF4ADE80),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProceedButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _availableSlots.isEmpty ? null : _proceedToBooking,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF5C63B),
          foregroundColor: const Color(0xFF1A1A1F),
          disabledBackgroundColor: const Color(0xFF3A3A40),
          disabledForegroundColor: const Color(0xFF8D8D93),
          elevation: _availableSlots.isEmpty ? 0 : 4,
          shadowColor: const Color(0xFFF5C63B).withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _availableSlots.isEmpty ? 'No Slots Available' : 'Continue to Payment',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            if (_availableSlots.isNotEmpty) ...[
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward_rounded, size: 22),
            ],
          ],
        ),
      ),
    );
  }
}
