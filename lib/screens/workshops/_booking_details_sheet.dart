import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/tokens/tokens.dart';
import '../../widgets/ui/ui.dart';

enum BookingSheetMode { details, edit }

class BookingDetailsBottomSheet extends StatefulWidget {
  final Map<String, dynamic> booking;
  final void Function(Map<String, dynamic> updates) onSave;
  final BookingSheetMode initialMode;

  const BookingDetailsBottomSheet({
    super.key,
    required this.booking,
    required this.onSave,
    this.initialMode = BookingSheetMode.details,
  });

  @override
  State<BookingDetailsBottomSheet> createState() => _BookingDetailsBottomSheetState();
}

class _BookingDetailsBottomSheetState extends State<BookingDetailsBottomSheet> {
  late BookingSheetMode _mode;

  // Edit form state
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
    'Cancelled',
    'Finished'
  ];

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _selectedServiceType = widget.booking['serviceName']?.toString() ?? 'General Service';
    if (!_serviceTypes.contains(_selectedServiceType)) {
      _selectedServiceType = 'General Service';
    }

    _selectedStatus = widget.booking['status']?.toString() ?? 'Pending';
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

    final Map<String, dynamic> updates = <String, dynamic>{
      'serviceName': _selectedServiceType,
      'status': _selectedStatus,
      'date': dateIsoString,
      'time': timeFormatted,
      'localDate': formattedDate,
      'localTime': timeWithPeriod,
    };

    widget.onSave(updates);
  }

  Future<void> _navigateToWorkshop() async {
    final String workshopName = widget.booking['workshopName']?.toString() ?? 'Workshop';
    final Uri webUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(workshopName)}',
    );
    try {
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch maps app')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error launching navigation')),
      );
    }
  }

  bool _isPastBooking() {
    final dateStr = widget.booking['date']?.toString() ?? '';
    if (dateStr.isEmpty) return false;
    final parsedDate = DateTime.tryParse(dateStr);
    if (parsedDate == null) return false;

    final today = DateTime.now();
    final bookingDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
    final todayDate = DateTime(today.year, today.month, today.day);
    return bookingDate.isBefore(todayDate);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;
    final bool isDark = theme.brightness == Brightness.dark;

    final String workshopName = widget.booking['workshopName']?.toString() ?? 'Workshop';
    final String serviceName = widget.booking['serviceName']?.toString() ?? 'General Service';
    final String dateString = widget.booking['date']?.toString() ?? '';
    final String timeString = widget.booking['time']?.toString() ?? '';
    final String status = widget.booking['status']?.toString() ?? 'Pending';
    final List<dynamic> specificServices = widget.booking['specificServices'] as List<dynamic>? ?? const [];

    final bool isPast = _isPastBooking();
    final bool isPendingOrConfirmed = status.toLowerCase() == 'pending' || status.toLowerCase() == 'confirmed';
    final bool isPendingConfirmation = isPast && isPendingOrConfirmed;

    // Render edit mode
    if (_mode == BookingSheetMode.edit) {
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
                    label: 'Back to Details',
                    onPressed: () => setState(() => _mode = BookingSheetMode.details),
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

    // Render details mode
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header workshop name and status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workshopName,
                      style: typography.headline.copyWith(color: colors.foreground),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      serviceName,
                      style: typography.bodyLarge.copyWith(
                        color: colors.foreground.withValues(alpha: colors.surfaceProminent),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              AppBadge(
                text: isPendingConfirmation ? 'Pending Confirmation' : status,
                kind: isPendingConfirmation
                    ? BadgeKind.warning
                    : (status.toLowerCase() == 'confirmed' || status.toLowerCase() == 'finished'
                        ? BadgeKind.success
                        : (status.toLowerCase() == 'cancelled' ? BadgeKind.error : BadgeKind.info)),
              ),
            ],
          ),
          SizedBox(height: spacing.lg),

          // Date and Time Box
          const AppSectionHeader(label: 'Appointment Details'),
          AppCard(
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 20,
                  color: colors.emerald500,
                ),
                SizedBox(width: spacing.sm),
                Text(
                  _formatIsoDate(dateString),
                  style: typography.bodyLarge.copyWith(color: colors.foreground),
                ),
                const Spacer(),
                Icon(
                  Icons.access_time_outlined,
                  size: 20,
                  color: colors.emerald500,
                ),
                SizedBox(width: spacing.sm),
                Text(
                  timeString,
                  style: typography.bodyLarge.copyWith(color: colors.foreground),
                ),
              ],
            ),
          ),
          SizedBox(height: spacing.lg),

          if (specificServices.isNotEmpty) ...[
            const AppSectionHeader(label: 'Selected Services'),
            Wrap(
              spacing: spacing.xs,
              runSpacing: spacing.xs,
              children: specificServices.map((s) => AppBadge(text: s.toString())).toList(),
            ),
            SizedBox(height: spacing.lg),
          ],

          // Gating alert for passed bookings
          if (isPendingConfirmation) ...[
            Container(
              padding: EdgeInsets.all(spacing.md),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(radii.medium),
                border: Border.all(color: colors.warning),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: colors.warning),
                      SizedBox(width: spacing.sm),
                      Expanded(
                        child: Text(
                          'Action Required',
                          style: typography.title.copyWith(color: colors.warning),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    'The scheduled date for this booking has passed. Please confirm if the service was finished, cancelled, or if you need to reschedule.',
                    style: typography.body.copyWith(color: colors.foreground),
                  ),
                  SizedBox(height: spacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: AppSecondaryButton(
                          label: 'Cancelled',
                          onPressed: () => widget.onSave({'status': 'Cancelled'}),
                        ),
                      ),
                      SizedBox(width: spacing.sm),
                      Expanded(
                        child: AppGradientButton(
                          label: 'Finished',
                          onPressed: () => widget.onSave({'status': 'Finished'}),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing.lg),
          ],

          // Buttons: Navigate + Edit
          Row(
            children: [
              Expanded(
                child: AppSecondaryButton(
                  label: 'Navigate',
                  icon: Icons.directions_outlined,
                  onPressed: _navigateToWorkshop,
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: AppGradientButton(
                  label: isPendingConfirmation ? 'Reschedule' : 'Edit Booking',
                  icon: Icons.edit_calendar_outlined,
                  onPressed: () => setState(() {
                    _mode = BookingSheetMode.edit;
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatIsoDate(String iso) {
    final DateTime? parsed = DateTime.tryParse(iso);
    if (parsed == null) {
      return iso.isEmpty ? '—' : iso;
    }
    return '${parsed.day}/${parsed.month}/${parsed.year}';
  }
}
