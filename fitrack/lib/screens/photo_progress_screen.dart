import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:dio/dio.dart' as dio;

import '../core/theme.dart';
import '../core/error_handler.dart';
import '../repositories/tracker_repository.dart';
import 'crop_normalization_editor.dart';
import '../models/dashboard.dart';
import '../providers/dashboard_provider.dart';
import '../providers/kyc_provider.dart';
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
  } catch (e) {
    // Let KYC errors surface so the screen can re-show the identity gate.
    if (ErrorHandler.isKycRequired(e)) rethrow;
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

  @override
  void initState() {
    super.initState();
    // Always refetch KYC from the API each time the photos screen is opened.
    // This ensures stale cache never bypasses the identity gate.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(kycStatusProvider);
    });
  }

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
      // Clear Flutter's in-memory image cache so the deleted photo is gone immediately.
      PaintingBinding.instance.imageCache.clear();
      ref.invalidate(dashboardProvider);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      if (ErrorHandler.isKycRequired(e)) {
        // KYC was revoked server-side — invalidate cache and show the gate.
        ref.invalidate(kycStatusProvider);
        return;
      }
      ErrorHandler.showSnackBar(context, ErrorHandler.getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _deleting.remove(photo.photoType));
    }
  }

  Future<void> _recropPhoto(ProgressPhoto photo) async {
    setState(() => _deleting[photo.photoType] = true); // Use deleting state for loading indicator

    try {
      if (photo.imageUrl == null) throw Exception('No original image found');

      // Download original image bytes
      final response = await dio.Dio().get<List<int>>(
        photo.imageUrl!,
        options: dio.Options(responseType: dio.ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(response.data!);

      if (!mounted) return;
      setState(() => _deleting.remove(photo.photoType));

      // Use rootNavigator so the crop editor lives on the root Navigator,
      // not GoRouter's Navigator. This prevents GoRouter page-reconciliation
      // (e.g. kycStatusProvider refetch) from interfering with the route.
      final result = await Navigator.of(context, rootNavigator: true).push<CropResult>(
        MaterialPageRoute(
          builder: (_) => CropNormalizationEditor(
            imageBytes: bytes,
            photoType: photo.photoType,
            excludeDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
          ),
        ),
      );

      if (result != null && mounted) {
        setState(() => _deleting[photo.photoType] = true);
        final repo = ref.read(trackerRepositoryProvider);
        await repo.uploadPhotoBytes(
          date: DateFormat('yyyy-MM-dd').format(_selectedDate),
          photoType: photo.photoType,
          bytes: result.originalBytes,
          normalizedBytes: result.normalizedBytes,
          cropTransform: result.cropTransform,
        );
        PaintingBinding.instance.imageCache.clear();
        ref.invalidate(dashboardProvider);
        _refresh();
      }
    } catch (e) {
      if (mounted) ErrorHandler.showSnackBar(context, ErrorHandler.getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _deleting.remove(photo.photoType));
    }
  }

  @override
  Widget build(BuildContext context) {
    // KYC gate — show verification prompt if not completed
    final kycAsync = ref.watch(kycStatusProvider);
    return kycAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => _KycGateScreen(),
      data: (kyc) {
        if (!kyc.kycCompleted) return _KycGateScreen();
        return _PhotosBody(
          selectedDate: _selectedDate,
          focusedDay: _focusedDay,
          deleting: _deleting,
          onDaySelected: (selected, focused) {
            setState(() {
              _selectedDate = selected;
              _focusedDay = focused;
            });
          },
          onRefresh: _refresh,
          onDelete: _deletePhoto,
          onRecrop: _recropPhoto,
          sessionAsync: ref.watch(photosByDateProvider(_selectedDate)),
        );
      },
    );
  }
}

// ── KYC gate screen ───────────────────────────────────────────────────────────

class _KycGateScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FitrackAppBar(title: 'Photos'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  LucideIcons.shieldAlert,
                  size: 34,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Identity Verification Required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Photo uploads are disabled until you complete identity verification. '
                'This is a one-time process.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'Start Verification',
                icon: LucideIcons.shieldCheck,
                onPressed: () => context.push('/kyc'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Photos body ───────────────────────────────────────────────────────────────

class _PhotosBody extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  final DateTime focusedDay;
  final Map<String, bool> deleting;
  final void Function(DateTime, DateTime) onDaySelected;
  final VoidCallback onRefresh;
  final Future<void> Function(ProgressPhoto) onDelete;
  final Future<void> Function(ProgressPhoto) onRecrop;
  final AsyncValue<PhotoSession?> sessionAsync;

  const _PhotosBody({
    required this.selectedDate,
    required this.focusedDay,
    required this.deleting,
    required this.onDaySelected,
    required this.onRefresh,
    required this.onDelete,
    required this.onRecrop,
    required this.sessionAsync,
  });

  @override
  ConsumerState<_PhotosBody> createState() => _PhotosBodyState();
}

class _PhotosBodyState extends ConsumerState<_PhotosBody> {
  Widget _buildEmpty() {
    final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
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
              DateFormat('MMMM d, yyyy').format(widget.selectedDate),
              style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 32),
            AppButton(
              label: 'Add Photos',
              icon: LucideIcons.plus,
              onPressed: () async {
                await context.push('/add-photos', extra: dateStr);
                widget.onRefresh();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotos(PhotoSession session) {
    final photoMap = {for (final p in session.photos) p.photoType: p};
    final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);

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
                      DateFormat('MMMM d, yyyy').format(widget.selectedDate),
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
                  widget.onRefresh();
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
            children: [
              for (int i = 0; i < _photoTypes.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _PhotoSlot(
                    label: _photoLabels[_photoTypes[i]]!,
                    photo: photoMap[_photoTypes[i]],
                    isDeleting: widget.deleting[_photoTypes[i]] == true,
                    onDelete: photoMap[_photoTypes[i]] != null
                        ? () => widget.onDelete(photoMap[_photoTypes[i]]!)
                        : null,
                    onCrop: photoMap[_photoTypes[i]] != null
                        ? () => widget.onRecrop(photoMap[_photoTypes[i]]!)
                        : null,
                    onTap: photoMap[_photoTypes[i]]?.displayUrl != null
                        ? () => _openPreview(photoMap, i)
                        : null,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _openPreview(Map<String, ProgressPhoto?> photoMap, int initialIndex) {
    final photos = _photoTypes
        .map((t) => photoMap[t])
        .where((p) => p?.displayUrl != null)
        .cast<ProgressPhoto>()
        .toList();
    if (photos.isEmpty) return;
    final type = _photoTypes[initialIndex];
    final startIndex = photos.indexWhere((p) => p.photoType == type);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      pageBuilder: (ctx, _, __) => PhotoPreviewSheet(
        photos: photos,
        initialIndex: startIndex < 0 ? 0 : startIndex,
        labels: _photoLabels,
      ),
    );
  }

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
            children: [
              for (int i = 0; i < _photoTypes.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _SlotSkeleton(label: _photoLabels[_photoTypes[i]]!),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            focusedDay: widget.focusedDay,
            selectedDayPredicate: (day) => isSameDay(widget.selectedDate, day),
            onDaySelected: widget.onDaySelected,
            calendarFormat: CalendarFormat.week,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
              ),
              todayDecoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
              ),
              defaultDecoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
              ),
              weekendDecoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
              ),
              outsideDecoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
              ),
              disabledDecoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const Divider(color: Color(0xFF1A1A1A), height: 1),
          Expanded(
            child: widget.sessionAsync.when(
              loading: () => _buildSkeleton(),
              error: (e, __) {
                // If the photos API says KYC is required, bust the cache so the
                // parent rebuilds with the identity gate.
                if (ErrorHandler.isKycRequired(e)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.invalidate(kycStatusProvider);
                  });
                }
                return _buildEmpty();
              },
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
}

// ── Photo slot (read-only with delete) ───────────────────────────────────────

class _PhotoSlot extends StatelessWidget {
  final String label;
  final ProgressPhoto? photo;
  final bool isDeleting;
  final VoidCallback? onDelete;
  final VoidCallback? onCrop;
  final VoidCallback? onTap;

  const _PhotoSlot({
    required this.label,
    required this.photo,
    required this.isDeleting,
    this.onDelete,
    this.onCrop,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: GestureDetector(
        onTap: onTap,
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
            if (photo != null && photo!.displayUrl != null)
              Image.network(
                photo!.displayUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primary, strokeWidth: 2)),
                errorBuilder: (_, __, ___) => const Center(
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
            if (photo != null && !isDeleting && (onDelete != null || onCrop != null))
              Positioned(
                top: 6,
                right: 6,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onCrop != null) ...[
                      _OverlayIconButton(
                        icon: LucideIcons.crop,
                        onTap: onCrop!,
                        tooltip: 'Recrop',
                        destructive: false,
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (onDelete != null)
                      _OverlayIconButton(
                        icon: LucideIcons.trash2,
                        onTap: onDelete!,
                        tooltip: 'Delete',
                        destructive: true,
                      ),
                  ],
                ),
              ),
          ],
          ),
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

// ── Full-screen photo preview with swipe ─────────────────────────────────────

class PhotoPreviewSheet extends StatefulWidget {
  final List<ProgressPhoto> photos;
  final int initialIndex;
  final Map<String, String> labels;

  const PhotoPreviewSheet({
    required this.photos,
    required this.initialIndex,
    required this.labels,
  });

  @override
  State<PhotoPreviewSheet> createState() => PhotoPreviewSheetState();
}

class PhotoPreviewSheetState extends State<PhotoPreviewSheet> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // ── Swipeable pages ──────────────────────────────────────
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (ctx, i) {
              final photo = widget.photos[i];
              return InteractiveViewer(
                child: Center(
                  child: Image.network(
                    photo.displayUrl!,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.primary, strokeWidth: 2)),
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(LucideIcons.imageOff,
                          color: Colors.white54, size: 48),
                    ),
                  ),
                ),
              );
            },
          ),

          // ── Label + indicator ────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  24, 32, 24, MediaQuery.of(context).padding.bottom + 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.labels[widget.photos[_currentIndex].photoType] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.photos.length > 1) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(widget.photos.length, (i) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _currentIndex ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _currentIndex
                                ? AppTheme.primary
                                : Colors.white38,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Close button ─────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 12,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primary, width: 1.5),
                ),
                child: const Icon(LucideIcons.x,
                    color: AppTheme.primary, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
