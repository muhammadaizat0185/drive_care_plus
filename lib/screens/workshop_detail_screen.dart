import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/workshop.dart';
import '../services/vehicle_insights.dart';
import '../widgets/star_rating.dart';

class WorkshopDetailScreen extends StatefulWidget {
  const WorkshopDetailScreen({super.key, required this.workshop});

  final Workshop workshop;

  @override
  State<WorkshopDetailScreen> createState() => _WorkshopDetailScreenState();
}

class _WorkshopDetailScreenState extends State<WorkshopDetailScreen> {
  WorkshopService? _selectedService;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedService = widget.workshop.services.first;
  }

  @override
  Widget build(BuildContext context) {
    final workshop = widget.workshop;

    return Scaffold(
      appBar: AppBar(title: Text(workshop.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workshop.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  StarRating(rating: workshop.rating),
                  const SizedBox(height: 6),
                  Text(
                    '${workshop.reviewCount} reviews • ${workshop.distance}',
                  ),
                  const SizedBox(height: 6),
                  Text(workshop.address),
                  const SizedBox(height: 12),
                  Text(workshop.description),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Price List',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final service in workshop.services) _serviceTile(service),
          const SizedBox(height: 12),
          _bookingCard(),
          const SizedBox(height: 12),
          _reviewsCard(),
        ],
      ),
    );
  }

  Widget _serviceTile(WorkshopService service) {
    final selected = _selectedService == service;

    return Card(
      child: ListTile(
        onTap: () => setState(() => _selectedService = service),
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(service.name),
        subtitle: Text(service.duration),
        trailing: Text(
          service.priceLabel,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: selected ? Theme.of(context).colorScheme.primary : null,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _bookingCard() {
    final service = _selectedService;
    final dateLabel = _selectedDate == null
        ? 'Select date'
        : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';
    final timeLabel = _selectedTime?.format(context) ?? 'Select time';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Book Appointment',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(dateLabel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text(timeLabel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (service != null)
              Text(
                'Selected: ${service.name} (${service.priceLabel})',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _requestQuote,
                    icon: const Icon(Icons.request_quote_outlined),
                    label: const Text('Request Quote'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _confirmBooking,
                    icon: const Icon(Icons.event_available_outlined),
                    label: const Text('Confirm'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ratings & Reviews',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final review in widget.workshop.reviews)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(review.author),
                subtitle: Text(review.comment),
                trailing: StarRating(
                  rating: review.rating.toDouble(),
                  size: 14,
                  showValue: false,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 10, minute: 0),
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _confirmBooking() {
    final service = _selectedService;
    if (service == null || _selectedDate == null || _selectedTime == null) {
      _showMessage('Please choose a service, date, and time first.');
      return;
    }

    final dateStr = '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';
    final timeStr = _selectedTime!.format(context);

    // Save locally to reactive cache
    final newBooking = {
      'workshopId': widget.workshop.id,
      'workshopName': widget.workshop.name,
      'serviceName': service.name,
      'servicePrice': service.price,
      'date': dateStr,
      'time': timeStr,
      'status': 'Confirmed',
    };
    VehicleInsights.instance.addBooking(newBooking);

    // Show booking animation success dialog
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('Booking Confirmed!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your appointment at ${widget.workshop.name} has been successfully saved in the cloud.',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.build_circle_outlined),
                title: const Text('Service'),
                subtitle: Text(service.name),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Date & Time'),
                subtitle: Text('$dateStr at $timeStr'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Estimated Price'),
                subtitle: Text(service.priceLabel),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Return to list
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );

    // Save Appointment to Cloud Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _saveBookingCloud(user.uid, service, dateStr, timeStr);
    }
  }

  Future<void> _saveBookingCloud(String uid, WorkshopService service, String dateStr, String timeStr) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('bookings')
          .add({
        'workshopId': widget.workshop.id,
        'workshopName': widget.workshop.name,
        'serviceName': service.name,
        'servicePrice': service.price,
        'date': dateStr,
        'time': timeStr,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore booking save error: $e');
    }
  }

  void _requestQuote() {
    final service = _selectedService;
    if (service == null) {
      _showMessage('Please choose a service before requesting a quote.');
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.mark_email_read_outlined, color: Colors.blue, size: 28),
              SizedBox(width: 8),
              Text('Quote Request Sent!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'We have transmitted your quote request for ${service.name} to ${widget.workshop.name}.',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              const Text(
                'When the workshop technicians respond with an estimate, you will receive a push notification reminder immediately.',
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
              },
              child: const Text('Understood'),
            ),
          ],
        );
      },
    );

    // Save Quote Request to Cloud Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _saveQuoteCloud(user.uid, service);
    }
  }

  Future<void> _saveQuoteCloud(String uid, WorkshopService service) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('quotes')
          .add({
        'workshopId': widget.workshop.id,
        'workshopName': widget.workshop.name,
        'serviceName': service.name,
        'servicePrice': service.price,
        'status': 'Pending Response',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore quote save error: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
