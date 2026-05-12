// ignore_for_file: deprecated_member_use
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/theme_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const routeName = '/settings';

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isConnected = user != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListenableBuilder(
        listenable: ThemeService.instance,
        builder: (context, child) {
          final themeService = ThemeService.instance;
          final activeColor = themeService.primaryColor;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Section: Premium Theme Customizer
              _buildSectionHeader(context, 'App Customization'),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.black.withOpacity(0.05)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Dark Mode',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Switch.adaptive(
                            value: themeService.themeMode == ThemeMode.dark,
                            onChanged: (isDark) {
                              themeService.setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
                            },
                            activeColor: activeColor,
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      const Text(
                        'Primary Accent Palette',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Customize your app brand color instantly',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      // Interactive color bubble list
                      SizedBox(
                        height: 54,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: ThemeService.presets.length,
                          separatorBuilder: (_, index) => const SizedBox(width: 14),
                          itemBuilder: (context, index) {
                            final name = ThemeService.presets.keys.elementAt(index);
                            final color = ThemeService.presets.values.elementAt(index);
                            final isSelected = activeColor.value == color.value;

                            return GestureDetector(
                              onTap: () {
                                themeService.setPrimaryColor(color);
                              },
                              child: Column(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.transparent,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: color.withOpacity(isSelected ? 0.4 : 0.1),
                                          blurRadius: isSelected ? 10 : 4,
                                          spreadRadius: isSelected ? 2 : 0,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    name.split(' ').first, // Show first name (e.g. "Emerald")
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? activeColor : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Section: Cloud Sync status
              _buildSectionHeader(context, 'Cloud Integration'),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.black.withOpacity(0.05)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: (isConnected ? Colors.green : Colors.grey).withOpacity(0.12),
                        child: Icon(
                          isConnected ? Icons.cloud_done : Icons.cloud_off,
                          color: isConnected ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isConnected ? 'Cloud Sync Enabled' : 'Offline Storage Mode',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isConnected
                                  ? 'Synced with ${user.email}'
                                  : 'Sync disabled (Authenticate to enable)',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Section: Info
              _buildSectionHeader(context, 'About App'),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.black.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    _buildListTile('App Version', 'v2.1.0-release', Icons.info_outline),
                    const Divider(height: 1),
                    _buildListTile('System Platform', 'Android API 34', Icons.phone_android_outlined),
                    const Divider(height: 1),
                    _buildListTile('Automotive Catalog', 'Malaysian Database v1.4', Icons.auto_awesome),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade600,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildListTile(String title, String subtitle, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade600),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
    );
  }
}
