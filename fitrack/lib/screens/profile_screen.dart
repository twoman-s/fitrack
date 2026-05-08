import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme.dart';
import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/kyc_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/user_profile_provider.dart';
import '../repositories/auth_repository.dart';
import '../repositories/tracker_repository.dart';
import '../screens/in_app_camera_screen.dart';
import '../services/face_verification_service.dart';
import '../widgets/app_button.dart';
import '../widgets/skeleton.dart';
import 'crop_normalization_editor.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final progressAsync = ref.watch(progressDataProvider);
    final statsAsync = ref.watch(statsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // ── App bar ────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppTheme.background,
            pinned: true,
            title: const Text(
              'Profile',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            centerTitle: false,
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.settings, color: AppTheme.textMuted, size: 20),
                onPressed: () {},
              ),
            ],
          ),

          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16, 8, 16, MediaQuery.of(context).padding.bottom + 90),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Avatar + name ────────────────────────────────────────
                profileAsync.when(
                  data: (profile) => _ProfileHeader(
                    profile: profile,
                    onEditTap: () => _showEditProfile(context, ref, profile),
                  ),
                  loading: () => const _ProfileHeaderSkeleton(),
                  error: (_, __) => const _ProfileHeader(profile: null, onEditTap: null),
                ),

                const SizedBox(height: 24),

                // ── Stats row ─────────────────────────────────────────────
                (progressAsync.isLoading || statsAsync.isLoading)
                    ? const _StatsRowSkeleton()
                    : _buildStatsRow(progressAsync, statsAsync),

                const SizedBox(height: 20),

                // ── Your Progress card ────────────────────────────────────
                progressAsync.isLoading
                    ? const _ProgressCardSkeleton()
                    : _buildProgressCard(context, progressAsync),

                const SizedBox(height: 20),

                // ── Menu items ────────────────────────────────────────────
                _MenuSection(children: [
                  _MenuItem(
                    icon: LucideIcons.checkSquare,
                    iconColor: AppTheme.primary,
                    title: 'My Goals',
                    subtitle: 'View and manage your goals',
                    onTap: () => context.push('/goals'),
                  ),
                  _MenuItem(
                    icon: LucideIcons.image,
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'Photos Progress',
                    subtitle: 'Track your body transformation',
                    onTap: () => context.push('/photos'),
                  ),
                  _MenuItem(
                    icon: LucideIcons.lock,
                    iconColor: const Color(0xFF3B82F6),
                    title: 'Change Password',
                    subtitle: 'Update your account password',
                    onTap: () => _showChangePassword(context, ref),
                  ),
                  _MenuItem(
                    icon: LucideIcons.scanFace,
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'Update Face Scan',
                    subtitle: 'Retake selfie for photo verification',
                    onTap: () => _updateFaceScan(context, ref),
                  ),
                ]),

                const SizedBox(height: 12),

                // ── Logout ────────────────────────────────────────────────
                _MenuSection(children: [
                  _MenuItem(
                    icon: LucideIcons.logOut,
                    iconColor: const Color(0xFFEF4444),
                    title: 'Logout',
                    subtitle: 'Sign out of your account',
                    titleColor: const Color(0xFFEF4444),
                    onTap: () => _confirmLogout(context, ref),
                  ),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Update face scan ─────────────────────────────────────────────────────

  Future<void> _updateFaceScan(BuildContext context, WidgetRef ref) async {
    // Open the in-app camera (FRONT pose) to capture a fresh selfie.
    final cropResult =
        await Navigator.of(context, rootNavigator: true).push<CropResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const InAppCameraScreen(photoType: 'FRONT'),
      ),
    );
    if (cropResult == null || !context.mounted) return;

    // Extract face embedding from the captured photo.
    final embedding = await FaceVerificationService.buildLandmarkEmbedding(
        cropResult.normalizedBytes);

    if (!context.mounted) return;

    if (embedding == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No face detected. Please try again in good lighting.')));
      return;
    }

    try {
      await ref.read(trackerRepositoryProvider).updateKycEmbedding(embedding);
      // Force a fresh fetch so the live camera overlay picks up the new embedding.
      ref.invalidate(kycStatusProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Face scan updated successfully.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update: $e')));
      }
    }
  }

  // ── Edit profile sheet ───────────────────────────────────────────────────

  void _showEditProfile(BuildContext context, WidgetRef ref, UserProfile profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EditProfileSheet(profile: profile, ref: ref),
    );
  }

  // ── Stats row ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow(AsyncValue progressAsync, AsyncValue statsAsync) {
    final gp = progressAsync.valueOrNull?.goalProgress;
    final stats = statsAsync.valueOrNull;

    final currentWeight = gp?.currentWeight;
    final goalWeight = gp?.targetWeight;
    final weightLeft = gp?.remaining;
    final daysLogged = stats?.daysLoggedMonth ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _StatCell(
            icon: LucideIcons.scale,
            iconColor: AppTheme.primary,
            value: currentWeight != null ? '${currentWeight.toStringAsFixed(1)} kg' : '--',
            label: 'Current Weight',
          ),
          _StatDivider(),
          _StatCell(
            icon: LucideIcons.target,
            iconColor: const Color(0xFF8B5CF6),
            value: goalWeight != null ? '${goalWeight.toStringAsFixed(1)} kg' : '--',
            label: 'Goal Weight',
          ),
          _StatDivider(),
          _StatCell(
            icon: LucideIcons.flame,
            iconColor: const Color(0xFFF59E0B),
            value: weightLeft != null ? '${weightLeft.toStringAsFixed(1)} kg' : '--',
            label: 'Weight Left',
          ),
          _StatDivider(),
          _StatCell(
            icon: LucideIcons.calendarDays,
            iconColor: const Color(0xFF3B82F6),
            value: '$daysLogged',
            label: 'Days Logged',
          ),
        ],
      ),
    );
  }

  // ── Progress card ────────────────────────────────────────────────────────

  Widget _buildProgressCard(BuildContext context, AsyncValue progressAsync) {
    final gp = progressAsync.valueOrNull?.goalProgress;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Progress',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/progress'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'View Progress',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(LucideIcons.chevronRight, color: AppTheme.primary, size: 15),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (gp == null)
            const Center(
              child: Text(
                'No active goal — set one to track progress.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            )
          else
            Row(
              children: [
                // Circular ring
                _MiniRing(percentage: gp.percentage),
                const SizedBox(width: 20),
                // Right side
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gp.percentage >= 100
                            ? 'Goal reached! 🎉'
                            : gp.percentage >= 50
                                ? "You're doing great!"
                                : "Keep going!",
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "You've ${gp.goalType == 'LOSE' ? 'lost' : 'gained'} "
                        "${gp.changed.abs().toStringAsFixed(1)} kg so far and "
                        "you're on track to reach your goal.",
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (gp.percentage / 100).clamp(0.0, 1.0),
                          backgroundColor: const Color(0xFF2D2D2D),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${gp.changed.abs().toStringAsFixed(1)} kg',
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(
                                  text: gp.goalType == 'LOSE' ? ' lost' : ' gained',
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${gp.remaining.toStringAsFixed(1)} kg to go',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Logout confirmation ──────────────────────────────────────────────────

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(authStateProvider.notifier).logout();
    }
  }

  // ── Change password sheet ────────────────────────────────────────────────

  void _showChangePassword(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ChangePasswordSheet(ref: ref),
    );
  }
}

// ── Profile header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final UserProfile? profile;
  final VoidCallback? onEditTap;
  const _ProfileHeader({required this.profile, required this.onEditTap});

  @override
  Widget build(BuildContext context) {
    final displayName = profile?.displayName ?? '';
    final sub = profile != null
        ? (profile!.email.isNotEmpty ? profile!.email : '@${profile!.username}')
        : '';

    return Row(
      children: [
        // Avatar with gradient ring
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF4ADE80), Color(0xFF16A34A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(2.5),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surface,
            ),
            child: const Icon(
              LucideIcons.user,
              color: AppTheme.primary,
              size: 36,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      displayName.isEmpty ? '...' : displayName,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(LucideIcons.badgeCheck, color: AppTheme.primary, size: 18),
                ],
              ),
              if (sub.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
              ],
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onEditTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Edit Profile',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(LucideIcons.pencil, color: AppTheme.primary, size: 13),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Stat cell ─────────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCell({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: AppTheme.divider);
  }
}

// ── Mini ring ─────────────────────────────────────────────────────────────────

class _MiniRing extends StatelessWidget {
  final double percentage;
  const _MiniRing({required this.percentage});

  @override
  Widget build(BuildContext context) {
    final pct = percentage.clamp(0.0, 100.0);
    return SizedBox(
      width: 90,
      height: 90,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 7,
              color: const Color(0xFF2D2D2D),
            ),
          ),
          SizedBox(
            width: 90,
            height: 90,
            child: CircularProgressIndicator(
              value: pct / 100,
              strokeWidth: 7,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const Text(
                'of goal',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Menu section + item ────────────────────────────────────────────────────────

class _MenuSection extends StatelessWidget {
  final List<Widget> children;
  const _MenuSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(height: 1, color: AppTheme.divider, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color? titleColor;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor ?? AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              color: titleColor?.withValues(alpha: 0.6) ?? AppTheme.textMuted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Edit profile bottom sheet ─────────────────────────────────────────────────

class _EditProfileSheet extends ConsumerStatefulWidget {
  final UserProfile profile;
  final WidgetRef ref;
  const _EditProfileSheet({required this.profile, required this.ref});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile.name);
    _emailCtrl = TextEditingController(text: widget.profile.email);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      await ref.read(userProfileProvider.notifier).save(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated.'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset + safeBottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Edit Profile',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          // Username (read-only)
          TextField(
            controller: TextEditingController(text: widget.profile.username),
            readOnly: true,
            style: const TextStyle(color: AppTheme.textMuted),
            decoration: InputDecoration(
              labelText: 'Username',
              labelStyle: const TextStyle(color: AppTheme.textMuted),
              filled: true,
              fillColor: const Color(0xFF0F0F0F),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: const Icon(LucideIcons.lock, color: AppTheme.textMuted, size: 16),
            ),
          ),
          const SizedBox(height: 12),
          _ProfileField(controller: _nameCtrl, label: 'Name', hint: 'Your display name'),
          const SizedBox(height: 12),
          _ProfileField(controller: _emailCtrl, label: 'Email', hint: 'your@email.com', keyboardType: TextInputType.emailAddress),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
          ],
          const SizedBox(height: 20),
          AppButton(
            label: 'Save Changes',
            isLoading: _isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;

  const _ProfileField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textMuted),
        labelStyle: const TextStyle(color: AppTheme.textMuted),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// ── Change password bottom sheet ──────────────────────────────────────────────

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _ChangePasswordSheet({required this.ref});

  @override
  ConsumerState<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentCtrl.text.trim();
    final newPass = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'All fields are required.');
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = 'New passwords do not match.');
      return;
    }
    if (newPass.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    try {
      await ref.read(authRepositoryProvider).changePassword(
        currentPassword: current,
        newPassword: newPass,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully.'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset + safeBottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Change Password',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          _PasswordField(
            controller: _currentCtrl,
            label: 'Current Password',
            obscure: _obscureCurrent,
            onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
          ),
          const SizedBox(height: 12),
          _PasswordField(
            controller: _newCtrl,
            label: 'New Password',
            obscure: _obscureNew,
            onToggle: () => setState(() => _obscureNew = !_obscureNew),
          ),
          const SizedBox(height: 12),
          _PasswordField(
            controller: _confirmCtrl,
            label: 'Confirm New Password',
            obscure: _obscureConfirm,
            onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
          ],
          const SizedBox(height: 20),
          AppButton(
            label: 'Update Password',
            isLoading: _isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textMuted),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? LucideIcons.eyeOff : LucideIcons.eye,
            color: AppTheme.textMuted,
            size: 18,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}

// ── Skeleton: profile header ────────────────────────────────────────────
class _ProfileHeaderSkeleton extends StatelessWidget {
  const _ProfileHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Row(
        children: [
          const SkeletonBox(width: 80, height: 80, radius: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 130, height: 20),
                SizedBox(height: 8),
                SkeletonBox(width: 90, height: 13),
                SizedBox(height: 14),
                SkeletonBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton: stats row ───────────────────────────────────────────────
class _StatsRowSkeleton extends StatelessWidget {
  const _StatsRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: List.generate(
            4,
            (_) => const Expanded(
              child: Column(
                children: [
                  SkeletonBox(width: 20, height: 20, radius: 10),
                  SizedBox(height: 8),
                  SkeletonBox(width: 48, height: 14),
                  SizedBox(height: 4),
                  SkeletonBox(width: 36, height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Skeleton: progress card (profile page) ──────────────────────────────
class _ProgressCardSkeleton extends StatelessWidget {
  const _ProgressCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonBox(width: 110, height: 16),
                SkeletonBox(width: 80, height: 13),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const SkeletonBox(width: 90, height: 90, radius: 45),
                const SizedBox(width: 20),
                Expanded(
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(height: 16),
                      SizedBox(height: 8),
                      SkeletonBox(height: 12),
                      SizedBox(height: 4),
                      SkeletonBox(width: 140, height: 12),
                      SizedBox(height: 12),
                      SkeletonBox(height: 6, radius: 4),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SkeletonBox(width: 60, height: 12),
                          SkeletonBox(width: 60, height: 12),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

