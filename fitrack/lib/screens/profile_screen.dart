import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMenuItem(LucideIcons.target, 'Goals'),
          _buildMenuItem(LucideIcons.bellRing, 'Reminders'),
          _buildMenuItem(LucideIcons.settings2, 'Units', value: 'kg'),
          const Divider(color: Color(0xFF1A1A1A), height: 32),
          _buildMenuItem(LucideIcons.upload, 'Backup & Sync'),
          _buildMenuItem(LucideIcons.download, 'Export Data'),
          _buildMenuItem(LucideIcons.settings, 'Settings'),
          const Divider(color: Color(0xFF1A1A1A), height: 32),
          _buildMenuItem(LucideIcons.helpCircle, 'Help & Feedback'),
          _buildMenuItem(LucideIcons.info, 'About Fitrack'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(authStateProvider.notifier).logout();
            },
            icon: const Icon(LucideIcons.logOut),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.1),
              foregroundColor: Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, {String? value}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF94A3B8)),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) 
            Text(value, style: const TextStyle(color: Color(0xFF94A3B8))),
          if (value != null) const SizedBox(width: 8),
          const Icon(LucideIcons.chevronRight, color: Color(0xFF94A3B8), size: 16),
        ],
      ),
      onTap: () {},
    );
  }
}
