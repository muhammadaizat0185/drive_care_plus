import 'package:flutter/material.dart';

import '../../core/theme/tokens/tokens.dart';
import '../../widgets/ui/ui.dart';

class EditBookingBottomSheet extends StatefulWidget {
  final Map<String, dynamic> booking;
  final void Function(Map<String, dynamic> updates) onSave;

  const EditBookingBottomSheet({
    super.key,
    required this.booking,
    required this.onSave,
  });

  @override
  State<EditBookingBottomSheet> createState() => _EditBookingBottomSheetState();
}

class _EditBookingBottomSheetState extends State<EditBookingBottomSheet> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  late String _selectedServiceType;
  late String _selectedStatus;

  final List<String> _serviceTypes = const <String>[
    'General Service',
    'Oil Change',
    'Tire Replacement',
    'Brake Repair',
    'Engine Tuning'
  ];

  final List<String> _statuses = const <String>[
    'Pending',
    'Confirmed',
    'Cancelled'
  ];

  @override
  void initState() {
    super.initState();
    _selectedServiceType = widget.booking['serviceName']?.toString() ?? 'General Service';
    if (!_serviceTypes.contains(_selectedServiceType)) {
      _selectedServiceType = 'General Service';
    }

    _selectedStatus = widget.booking['status']?.toString() ?? 'Pending';
    // Match case insensitivity if needed
    final matchedStatus = _statuses.firstWhere(
      (s) => s.toLowerCase() == _selectedStatus.toLowerCase(),
      orElse: () => 'Pending',
    );
    _selectedStatus = matchedStatus;

    _selectedDate = _parseDate(widget.booking['date']?.toString() ?? '');
    _selectedTime = _parseTime(widget.booking['time']?.toString() ?? '');
  }

  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    final parsedIso = DateTime.tryParse(dateStr);
    if (parsedIso != null) return parsedIso;
    final parts = dateStr.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  TimeOfDay? _parseTime(String timeStr) {
    if (timeStr.isEmpty) return null;
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      final hourPart = parts[0];
      final minutePart = parts[1].split(' ').first;
      final hour = int.tryParse(hourPart);
      final minute = int.tryParse(minutePart);
      if (hour != null && minute != null) {
        var adjustedHour = hour;
        if (timeStr.toUpperCase().contains('PM') && hour < 12) {
          adjustedHour += 12;
        } else if (timeStr.toUpperCase().contains('AM') && hour == 12) {
          adjustedHour = 0;
        }
        return TimeOfDay(hour: adjustedHour, minute: minute);
      }
    }
    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
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

  void _save() {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time')),
      );
      return;
    }

    final String dateIsoString = _selectedDate!.toIso8601String();
    final String formattedDate = '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';
    final String timeFormatted = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';
    final String timeWithPeriod = _selectedTime!.format(context);

    // Return a map with both ISO formats (for Firestore) and custom formats (for VehicleInsights)
    final Map<String, dynamic> updates = <String, dynamic>{
      'serviceName': _selectedServiceType,
      'status': _selectedStatus,
      'date': dateIsoString, // Firestore
      'time': timeFormatted, // Firestore
      'localDate': formattedDate, // SharedPreferences local
      'localTime': timeWithPeriod, // SharedPreferences local
    };

    widget.onSave(updates);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;
    final bool isDark = theme.brightness == Brightness.dark;

    final String workshopName = widget.booking['workshopName']?.toString() ?? 'Workshop';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Edit Appointment',
            style: typography.headline.copyWith(color: colors.foreground),
          ),
          SizedBox(height: spacing.xs),
          Text(
            workshopName,
            style: typography.bodyLarge.copyWith(
              color: colors.foreground.withValues(alpha: colors.surfaceProminent),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: spacing.lg),

          const AppSectionHeader(label: 'Booking Status'),
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            style: typography.body.copyWith(color: colors.foreground),
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: spacing.md,
                vertical: spacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.border),
              ),
            ),
            items: _statuses.map((String status) {
              return DropdownMenuItem<String>(
                value: status,
                child: Text(status),
              );
            }).toList(),
            onChanged: (String? val) {
              if (val != null) {
                setState(() => _selectedStatus = val);
              }
            },
          ),
          SizedBox(height: spacing.lg),

          const AppSectionHeader(label: 'Service Type'),
          DropdownButtonFormField<String>(
            value: _selectedServiceType,
            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            style: typography.body.copyWith(color: colors.foreground),
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: spacing.md,
                vertical: spacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.border),
              ),
            ),
            items: _serviceTypes.map((String type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (String? val) {
              if (val != null) {
                setState(() => _selectedServiceType = val);
              }
            },
          ),
          SizedBox(height: spacing.lg),

          const AppSectionHeader(label: 'Schedule Appointment'),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _selectedDate == null
                        ? 'Select Date'
                        : '${_selectedDate!.day}/${_selectedDate!.month}',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: spacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.access_time, size: 16),
                  label: Text(
                    _selectedTime == null
                        ? 'Select Time'
                        : _selectedTime!.format(context),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: spacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.xl),

          Row(
            children: <Widget>[
              Expanded(
                child: AppSecondaryButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: AppGradientButton(
                  label: 'Save Changes',
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
