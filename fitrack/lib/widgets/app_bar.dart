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

  double get _toolbarHeight => isHome ? 76.0 : 64.0;

  @override
  Size get preferredSize => Size.fromHeight(_toolbarHeight + 1.0); // +1 for divider

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return AppBar(
      toolbarHeight: _toolbarHeight,
      backgroundColor: AppTheme.background,
      surfaceTintColor: AppTheme.surfaceHighlight,
      scrolledUnderElevation: 8.0,
      elevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      leading: _buildLeading(context, canPop),
      title: _buildTitle(),
      titleSpacing: isHome ? 24.0 : (canPop ? 0.0 : 20.0),
      actions: isHome
          ? [
              Padding(
                padding: const EdgeInsets.only(right: 24.0),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ]
          : (actions != null
              ? [
                  ...actions!,
                  const SizedBox(width: 8),
                ]
              : null),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(
          color: AppTheme.divider.withOpacity(0.5),
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
      return const Text(
        'Fitrack',
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
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
