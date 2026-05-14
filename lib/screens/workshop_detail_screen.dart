import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/workshop.dart';
import '../services/google_maps_service.dart';
import '../services/workshop_firebase_service.dart';
import '../widgets/star_rating.dart';
import '../widgets/rating_form_dialog.dart';

class WorkshopDetailScreen extends StatefulWidget {
  const WorkshopDetailScreen({super.key, required this.workshop});

  final Workshop workshop;

  @override
  State<WorkshopDetailScreen> createState() => _WorkshopDetailScreenState();
}

class _WorkshopDetailScreenState extends State<WorkshopDetailScreen> {
  late Workshop _currentWorkshop;
  bool _isLoadingDetails = false;
  final WorkshopFirebaseService _firebaseService = WorkshopFirebaseService();
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _selectedServiceType = 'General Service';
  final List<String> _serviceTypes = [
    'General Service', 
    'Oil Change', 
    'Tire Replacement', 
    'Brake Repair', 
    'Car Wash', 
    'Engine Tuning'
  ];

  @override
  void initState() {
    super.initState();
    // Initialize with provided workshop data
    _currentWorkshop = widget.workshop;
    _fetchDeepDetails();
  }

  Future<void> _fetchDeepDetails() async {
    if (!mounted) return;
    setState(() => _isLoadingDetails = true);
    
    try {
      final details = await GoogleMapsService.getWorkshopDetails(_currentWorkshop.id);
      
      if (details != null && mounted) {
        setState(() {
          _currentWorkshop = Workshop(
            id: _currentWorkshop.id,
            name: _currentWorkshop.name,
            address: _currentWorkshop.address,
            rating: _currentWorkshop.rating,
            reviewCount: _currentWorkshop.reviewCount,
            location: _currentWorkshop.location,
            isGooglePlace: true,
            openingHours: details['regularOpeningHours'] ?? _currentWorkshop.openingHours,
            photos: (details['photos'] as List?)?.map((p) => p['name'] as String).toList() ?? _currentWorkshop.photos,
            types: _currentWorkshop.types,
            isOpenNow: (details['regularOpeningHours'] != null) 
                ? details['regularOpeningHours']['openNow'] as bool? 
                : _currentWorkshop.isOpenNow,
          );
        });
      } else {
        // Fallback: If details API fails, we still have Tier 1 data
        debugPrint('Details API returned null, using Tier 1 data');
      }
    } catch (e) {
      debugPrint('Error fetching deep details: $e');
    } finally {
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  Future<void> _launchNavigation() async {
    if (_currentWorkshop.location == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location coordinates not available')),
      );
      return;
    }
    
    final lat = _currentWorkshop.location!.latitude;
    final lng = _currentWorkshop.location!.longitude;
    final url = Uri.parse('google.navigation:q=$lat,$lng');
    final webUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _currentWorkshop.name.isEmpty ? 'Workshop Details' : _currentWorkshop.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            onPressed: _launchNavigation,
            icon: const Icon(Icons.directions),
            tooltip: 'Navigate',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0F172A), const Color(0xFF022C22)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Content
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              _buildHeaderCard(isDark, primaryColor),
              const SizedBox(height: 20),
              
              if (_isLoadingDetails)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                _buildInfoSection(isDark, primaryColor),
                const SizedBox(height: 20),
                if (!_currentWorkshop.isGasStation) ...[
                  _buildBookingSection(isDark, primaryColor),
                  const SizedBox(height: 20),
                ],
                _buildReviewSection(isDark, primaryColor),
              ],
            ],
          ),
        ],
      ),
      bottomNavigationBar: _currentWorkshop.isGasStation 
          ? null 
          : _buildBottomActionBar(primaryColor, isDark),
    );
  }

  Widget _buildHeaderCard(bool isDark, Color primaryColor) {
    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentWorkshop.name,
              style: TextStyle(
                fontWeight: FontWeight.w900, 
                fontSize: 22,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                StarRating(rating: _currentWorkshop.rating),
                const SizedBox(width: 8),
                Text(
                  '(${_currentWorkshop.reviewCount} Reviews)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _launchNavigation,
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 18, color: primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentWorkshop.address,
                      style: TextStyle(
                        fontSize: 14, 
                        color: isDark ? Colors.white70 : Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const Icon(Icons.open_in_new, size: 14, color: Colors.grey),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(bool isDark, Color primaryColor) {
    // Dummy Data Fallback for Hours
    final hours = _currentWorkshop.openingHours?['weekdayDescriptions'] as List? ?? [
      'Monday: 9:00 AM – 6:00 PM',
      'Tuesday: 9:00 AM – 6:00 PM',
      'Wednesday: 9:00 AM – 6:00 PM',
      'Thursday: 9:00 AM – 6:00 PM',
      'Friday: 9:00 AM – 6:00 PM',
      'Saturday: 10:00 AM – 4:00 PM',
      'Sunday: Closed',
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'WORKSHOP INFO',
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.w900, 
              color: primaryColor.withOpacity(0.8), 
              letterSpacing: 1.2,
            ),
          ),
        ),
        Card(
          elevation: 0,
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 18, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      'Opening Hours', 
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...hours.map((h) {
                  final parts = h.toString().split(': ');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(parts.first, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
                        Text(parts.length > 1 ? parts.last : '', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingSection(bool isDark, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'BOOK APPOINTMENT',
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.w900, 
              color: primaryColor.withOpacity(0.8), 
              letterSpacing: 1.2,
            ),
          ),
        ),
        Card(
          elevation: 0,
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: primaryColor.withOpacity(0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedServiceType,
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Service Type',
                    labelStyle: const TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  items: _serviceTypes.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedServiceType = val);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(_selectedDate == null ? 'Select Date' : '${_selectedDate!.day}/${_selectedDate!.month}'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.access_time, size: 18),
                        label: Text(_selectedTime == null ? 'Select Time' : _selectedTime!.format(context)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _confirmBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: primaryColor.withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Schedule Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewSection(bool isDark, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'COMMUNITY REVIEWS',
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.w900, 
                  color: primaryColor.withOpacity(0.8), 
                  letterSpacing: 1.2,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _openRatingsDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Write Review'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<WorkshopReview>>(
          stream: _firebaseService.getInternalReviews(_currentWorkshop.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ));
            }
            
            final reviews = snapshot.data ?? [];
            if (reviews.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.rate_review_outlined, color: Colors.grey.withOpacity(0.3), size: 48),
                      const SizedBox(height: 12),
                      const Text('No community reviews yet.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: reviews.map((r) => _buildReviewTile(r, isDark)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildReviewTile(WorkshopReview review, bool isDark) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.03)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(review.author, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                StarRating(rating: review.rating, size: 14),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              review.comment, 
              style: TextStyle(
                fontSize: 13, 
                height: 1.5, 
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            if (review.timestamp != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '${review.timestamp!.day}/${review.timestamp!.month}/${review.timestamp!.year}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(Color primaryColor, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 20, 
        right: 20, 
        top: 16, 
        bottom: MediaQuery.of(context).padding.bottom + 16
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ESTIMATED TOTAL', 
                  style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'RM 150 - 500', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: primaryColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _confirmBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 4,
                shadowColor: primaryColor.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  void _confirmBooking() async {
    if (_selectedDate == null || _selectedTime == null) {
      _showMessage('Please select date and time');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('Please login to book');
      return;
    }

    final bookingData = {
      'userId': user.uid,
      'place_id': _currentWorkshop.id,
      'workshopName': _currentWorkshop.name,
      'serviceName': _selectedServiceType,
      'date': _selectedDate!.toIso8601String(),
      'time': '${_selectedTime!.hour}:${_selectedTime!.minute}',
      'totalCost': 150.0, // Dummy fixed cost
      'status': 'Pending',
    };

    await _firebaseService.createBooking(bookingData);
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Booking Successful!', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Your appointment has been scheduled and saved to our database.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context); // Go back to list
              }, 
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  void _openRatingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => RatingFormDialog(
        onSubmitted: (review) async {
          await _firebaseService.submitReview(_currentWorkshop.id, review);
          _showMessage('Review submitted!');
        },
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
