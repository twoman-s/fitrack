import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme.dart';
import '../core/error_handler.dart';
import '../repositories/tracker_repository.dart';
import '../models/dashboard.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/app_bar.dart';
import '../widgets/app_button.dart';
import '../widgets/skeleton.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final photosByDateProvider =
    FutureProvider.family.autoDispose<PhotoSession?, DateTime>((ref, date) async {
  final repo = ref.watch(trackerRepositoryProvider);
  final dateStr = DateFormat('yyyy-MM-dd').format(date);
  try {
    return await repo.getPhotosByDate(dateStr);
  } catch (_) {
    return null;
  }
});

// ── Constants ─────────────────────────────────────────────────────────────────

const _photoTypes = ['FRONT', 'SIDE', 'BACK'];
const _photoLabels = {
  'FRONT': 'Front',
  'SIDE': 'Side',
  'BACK': 'Back',
};

// ── Screen ────────────────────────────────────────────────────────────────────

class PhotoProgressScreen extends ConsumerStatefulWidget {
  const PhotoProgressScreen({super.key});

  @override
  ConsumerState<PhotoProgressScreen> createState() => _PhotoProgressScreenState();
}

class _PhotoProgressScreenState extends ConsumerState<PhotoProgressScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  final Map<String, bool> _deleting = {};

  void _refresh() => ref.invalidate(photosByDateProvider(_selectedDate));

  Future<void> _deletePhoto(ProgressPhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Photo',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Delete this ${_photoLabels[photo.photoType] ?? photo.photoType} photo? This cannot be undone.',
          style: const TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting[photo.photoType] = true);
    try {
      await ref.read(trackerRepositoryProvider).deletePhoto(photo.id);
      ref.invalidate(dashboardProvider);
      _refresh();
    } catch (e) {
      if (mounted) ErrorHandler.showSnackBar(context, ErrorHandler.getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _deleting.remove(photo.photoType));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(photosByDateProvider(_selectedDate));

    return Scaffold(
      appBar: FitrackAppBar(
        title: 'Photos',
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.arrowLeftRight, size: 20),
            onPressed: () => context.push('/compare'),
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.now(),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDate = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            calendarFormat: CalendarFormat.week,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: const CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              todayDecoration: BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const Divider(color: Color(0xFF1A1A1A), height: 1),
          Expanded(
            child: sessionAsync.when(
              loading: () => _buildSkeleton(),
              error: (_, __) => _buildEmpty(),
              data: (session) {
                final hasPhotos = session != null && session.photos.isNotEmpty;
                return hasPhotos ? _buildPhotos(session) : _buildEmpty();
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ─────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(LucideIcons.camera,
                  size: 32, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 20),
            const Text(
              'No photos yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMMM d, yyyy').format(_selectedDate),
              style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 32),
            AppButton(
              label: 'Add Photos',
              icon: LucideIcons.plus,
              onPressed: () async {
                await context.push('/add-photos', extra: dateStr);
                _refresh();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Photos view ─────────────────────────────────────────────────────────────

  Widget _buildPhotos(PhotoSession session) {
    final photoMap = {for (final p in session.photos) p.photoType: p};
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).padding.bottom + 84),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMMM d, yyyy').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${session.photos.length} of 3 photos',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () async {
                  await context.push('/add-photos', extra: dateStr);
                  _refresh();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.pencil,
                          size: 13, color: AppTheme.primary),
                      SizedBox(width: 6),
                      Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _photoTypes.asMap().entries.map((entry) {
              final i = entry.key;
              final type = entry.value;
              final photo = photoMap[type];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: i == 0 ? 0 : 5,
                    right: i == _photoTypes.length - 1 ? 0 : 5,
                  ),
                  child: _PhotoSlot(
                    label: _photoLabels[type]!,
                    photo: photo,
                    isDeleting: _deleting[type] == true,
                    onDelete: photo != null ? () => _deletePhoto(photo) : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Skeleton ─────────────────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonShimmer(
            child: Container(
              height: 24,
              width: 180,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _photoTypes.asMap().entries.map((entry) {
              final i = entry.key;
              final type = entry.value;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: i == 0 ? 0 : 5,
                    right: i == _photoTypes.length - 1 ? 0 : 5,
                  ),
                  child: _SlotSkeleton(label: _photoLabels[type]!),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Photo slot (read-only with delete) ───────────────────────────────────────

class _PhotoSlot extends StatelessWidget {
  final String label;
  final ProgressPhoto? photo;
  final bool isDeleting;
  final VoidCallback? onDelete;

  const _PhotoSlot({
    required this.label,
    required this.photo,
    required this.isDeleting,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: photo == null ? AppTheme.divider : Colors.transparent,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo != null && photo!.imageUrl != null)
              CachedNetworkImage(
                imageUrl: photo!.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primary, strokeWidth: 2),
                ),
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(LucideIcons.imageOff,
                      color: AppTheme.textMuted, size: 32),
                ),
              )
            else
              const Center(
                child: Icon(LucideIcons.imageMinus,
                    color: AppTheme.textMuted, size: 28),
              ),
            // ── Label gradient overlay ──────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.fromLTRB(6, 18, 6, 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.65),
                    ],
                  ),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (isDeleting)
              Container(
                color: Colors.black.withValues(alpha: 0.55),
                child: const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primary, strokeWidth: 2),
                ),
              ),
            if (photo != null && !isDeleting && onDelete != null)
              Positioned(
                top: 6,
                right: 6,
                child: _OverlayIconButton(
                  icon: LucideIcons.trash2,
                  onTap: onDelete!,
                  tooltip: 'Delete',
                  destructive: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Overlay icon button ───────────────────────────────────────────────────────

class _OverlayIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool destructive;

  const _OverlayIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 15,
            color: destructive ? const Color(0xFFEF4444) : Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── Skeleton slot ─────────────────────────────────────────────────────────────

class _SlotSkeleton extends StatelessWidget {
  final String label;
  const _SlotSkeleton({required this.label});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SkeletonShimmer(
          child: Container(
            color: const Color(0xFF2A2A2A),
          ),
        ),
      ),
    );
  }
}
