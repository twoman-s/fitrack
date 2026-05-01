import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme.dart';

/// A single, reusable app bar for all screens.
///
/// - [isHome] = true  → shows logo icon + "Fitrack" wordmark, no back button,
///                       slightly taller toolbar (68 dp).
/// - [isHome] = false → left-aligned [title], auto back-button with a
///                      custom arrow icon when the route can be popped,
///                      standard 56 dp height.
///
/// The 1 dp divider at the bottom and `scrolledUnderElevation: 0` together
/// ensure the bar never changes colour when content scrolls behind it.
class FitrackAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FitrackAppBar({
    super.key,
    this.isHome = false,
    this.title,
    this.actions,
  });

  final bool isHome;
  final String? title;
  final List<Widget>? actions;

  double get _toolbarHeight => isHome ? 68.0 : 56.0;

  @override
  Size get preferredSize => Size.fromHeight(_toolbarHeight + 1.0); // +1 for divider

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return AppBar(
      toolbarHeight: _toolbarHeight,
      backgroundColor: AppTheme.background,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      leading: _buildLeading(context, canPop),
      title: _buildTitle(),
      titleSpacing: isHome ? 20.0 : (canPop ? 0.0 : 20.0),
      actions: actions != null
          ? [
              ...actions!,
              const SizedBox(width: 8),
            ]
          : null,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(
          color: AppTheme.divider,
          height: 1.0,
        ),
      ),
    );
  }

  Widget? _buildLeading(BuildContext context, bool canPop) {
    if (isHome) return null;
    if (!canPop) return null;
    return IconButton(
      icon: const Icon(LucideIcons.arrowLeft, size: 22),
      color: AppTheme.textPrimary,
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }

  Widget? _buildTitle() {
    if (isHome) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/app_icon.png',
              width: 34,
              height: 34,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Fitrack',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      );
    }

    if (title == null) return null;

    return Text(
      title!,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    );
  }
}
