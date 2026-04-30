import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

class MainScaffold extends ConsumerWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: child,
      bottomNavigationBar: _buildBottomNav(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showQuickAddOptions(context);
        },
        backgroundColor: const Color(0xFF22C55E),
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    int currentIndex = 0;
    if (location.startsWith('/home')) currentIndex = 0;
    if (location.startsWith('/progress')) currentIndex = 1;
    if (location.startsWith('/photos')) currentIndex = 2;
    if (location.startsWith('/profile')) currentIndex = 3;

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        switch (index) {
          case 0:
            context.go('/home');
            break;
          case 1:
            context.go('/progress');
            break;
          case 2:
            context.go('/photos');
            break;
          case 3:
            context.go('/profile');
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(LucideIcons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(LucideIcons.lineChart),
          label: 'Progress',
        ),
        BottomNavigationBarItem(
          icon: Icon(LucideIcons.image),
          label: 'Photos',
        ),
        BottomNavigationBarItem(
          icon: Icon(LucideIcons.moreHorizontal),
          label: 'More',
        ),
      ],
    );
  }

  void _showQuickAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.scale, color: Color(0xFF22C55E)),
                  title: const Text('Log Weight', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/add-weight');
                  },
                ),
                ListTile(
                  leading: const Icon(LucideIcons.camera, color: Color(0xFF22C55E)),
                  title: const Text('Add Progress Photo', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/upload-photo');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
