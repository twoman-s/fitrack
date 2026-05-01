import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/dashboard_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/user_profile_provider.dart';

class MainScaffold extends ConsumerWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  static const _routes = ['/home', '/progress', '/photos', '/profile'];
  static const _icons = [
    LucideIcons.home,
    LucideIcons.lineChart,
    LucideIcons.image,
    LucideIcons.userCircle2,
  ];
  static const _labels = ['Home', 'Progress', 'Photos', 'Profile'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    int currentIndex = 0;
    for (int i = 0; i < _routes.length; i++) {
      if (location.startsWith(_routes[i])) {
        currentIndex = i;
        break;
      }
    }

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: _BottomBar(
        currentIndex: currentIndex,
        onTap: (index) {
          HapticFeedback.lightImpact();
          switch (index) {
            case 0:
              ref.invalidate(dashboardProvider);
            case 1:
              ref.invalidate(progressDataProvider);
              ref.invalidate(statsProvider);
            case 3:
              ref.invalidate(userProfileProvider);
              ref.invalidate(progressDataProvider);
              ref.invalidate(statsProvider);
          }
          context.go(_routes[index]);
        },
        icons: _icons,
        labels: _labels,
        onFabTap: currentIndex == 2
            ? () => context.push('/add-photos',
                extra: DateFormat('yyyy-MM-dd').format(DateTime.now()))
            : () => _showQuickAddOptions(context),
        fabIcon: currentIndex == 2 ? LucideIcons.camera : LucideIcons.plus,
      ),
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
                    context.push('/add-photos',
                        extra: DateFormat('yyyy-MM-dd').format(DateTime.now()));
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

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.currentIndex,
    required this.onTap,
    required this.icons,
    required this.labels,
    required this.onFabTap,
    required this.fabIcon,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<IconData> icons;
  final List<String> labels;
  final VoidCallback onFabTap;
  final IconData fabIcon;

  static const Color primary = Color(0xFF22C55E);
  static const Color background = Color(0xFF111111);
  static const Color border = Color(0xFF2A2A2A);
  static const Color inactive = Color(0xFF4B5563);

  static const double barHeight = 64;
  static const double radius = 12;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding + 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: barHeight,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .45),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(
                  icons.length,
                  (i) => Expanded(
                    child: _NavItem(
                      icon: icons[i],
                      label: labels[i],
                      selected: currentIndex == i,
                      onTap: () => onTap(i),
                      primary: primary,
                      inactive: inactive,
                      radius: radius,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          _FabButton(
            icon: fabIcon,
            onTap: onFabTap,
            primary: primary,
            height: barHeight,
            radius: radius,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nav Item
// ---------------------------------------------------------------------------

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.primary,
    required this.inactive,
    required this.radius,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color primary;
  final Color inactive;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 64,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: selected
                  ? primary.withValues(alpha: .15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: selected ? primary : inactive,
                  ),

                  AnimatedSwitcher(
                    duration:
                        const Duration(milliseconds: 220),
                    transitionBuilder:
                        (child, animation) =>
                            SizeTransition(
                      sizeFactor: animation,
                      axis: Axis.horizontal,
                      child: child,
                    ),
                    child: selected
                        ? Padding(
                            key: const ValueKey("label"),
                            padding:
                                const EdgeInsets.only(
                              left: 6,
                            ),
                            child: Text(
                              label,
                              maxLines: 1,
                              style: TextStyle(
                                color: primary,
                                fontSize: 13,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          )
                        : const SizedBox(
                            key: ValueKey("empty"),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FAB
// ---------------------------------------------------------------------------

class _FabButton extends StatelessWidget {
  const _FabButton({
    required this.icon,
    required this.onTap,
    required this.primary,
    required this.height,
    required this.radius,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color primary;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: height,
        height: height,
        decoration: BoxDecoration(
          color: primary,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: .35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.black,
          size: 28,
        ),
      ),
    );
  }
}