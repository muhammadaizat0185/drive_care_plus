import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const routeName = '/notifications';

  @override
  Widget build(BuildContext context) {
    final reminders = [
      'Oil change reminder will be sent 7 days before due date.',
      'Workshop quotation reply will trigger a push notification.',
      'Insurance expiry reminder will be sent 30 days before expiry.',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
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
                    'Push Notification Plan',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Dummy reminder center. Later this connects to Firebase Cloud Messaging.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final reminder in reminders)
            Card(
              child: ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(reminder),
              ),
            ),
        ],
      ),
    );
  }
}
