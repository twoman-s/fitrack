import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/error_handler.dart';
import '../core/theme.dart';
import '../models/dashboard.dart';
import '../providers/dashboard_provider.dart';
import '../providers/kyc_provider.dart';
import '../repositories/tracker_repository.dart';
import '../widgets/app_bar.dart';
import '../widgets/app_button.dart';
import 'crop_normalization_editor.dart';
import 'in_app_camera_screen.dart';
import 'photo_progress_screen.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _photoTypes = ['FRONT', 'SIDE', 'BACK'];
const _photoLabels = {
  'FRONT': 'Front',
  'SIDE': 'Side',
  'BACK': 'Back',
};

// ── Screen ────────────────────────────────────────────────────────────────────

class AddPhotosScreen extends ConsumerStatefulWidget {
  /// ISO date string `yyyy-MM-dd` for the session being edited.
  final String date;

  const AddPhotosScreen({super.key, required this.date});

  @override
  ConsumerState<AddPhotosScreen> createState() => _AddPhotosScreenState();
}

class _AddPhotosScreenState extends ConsumerState<AddPhotosScreen> {
  /// Sentinel map indicating which photo types have been locally selected.
  /// Values are either [XFile] (gallery) or [CropResult] (camera) — only the
  /// key is ever read; bytes are stored separately in [_previewBytes].
  final Map<String, Object> _selected = {};

  /// Preloaded bytes for preview, keyed by photo type.
  final Map<String, Uint8List> _previewBytes = {};

  bool _isSaving = false;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
  }

  // ── Pick image ─────────────────────────────────────────────────────────────

  Future<void> _pick(String photoType, ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1080,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _selected[photoType] = picked; // XFile sentinel
      _previewBytes[photoType] = bytes;
    });
  }

  Future<void> _showPicker(String photoType) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.surface,
      useRootNavigator: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              '${_photoLabels[photoType]} Photo',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _SourceButton(
                    icon: LucideIcons.camera,
                    label: 'Camera',
                    onTap: () => Navigator.pop(ctx, ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SourceButton(
                    icon: LucideIcons.image,
                    label: 'Gallery',
                    onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    if (source == ImageSource.camera) {
      // Push as CropResult — InAppCameraScreen returns a CropResult (via
      // CropNormalizationEditor), not a raw XFile. Using the wrong type
      // parameter causes a runtime TypeError inside Route.didComplete which
      // permanently leaves _debugLocked=true on Flutter's navigator.
      final cropResult =
          await Navigator.of(context, rootNavigator: true).push<CropResult>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => InAppCameraScreen(photoType: photoType),
        ),
      );
      if (cropResult == null || !mounted) return;
      setState(() {
        _selected[photoType] = cropResult; // CropResult sentinel
        _previewBytes[photoType] = cropResult.normalizedBytes;
      });
    } else {
      await _pick(photoType, source);
    }
  }

  // ── Preview ───────────────────────────────────────────────────────────────

  void _openPreview(Map<String, ProgressPhoto> existing, int initialIndex) {
    final photos = _photoTypes
        .map((t) => existing[t])
        .where((p) => p?.imageUrl != null)
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
  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_selected.isEmpty) {
      ErrorHandler.showSnackBar(context, 'Select at least one photo.');
      return;
    }

    setState(() => _isSaving = true);

    final repo = ref.read(trackerRepositoryProvider);
    int uploaded = 0;
    String? lastError;

    final date = DateTime.parse(widget.date);

    for (final entry in _selected.entries) {
      try {
        final bytes = _previewBytes[entry.key];
        if (bytes == null) continue;
        final filename = '${widget.date}_${entry.key.toLowerCase()}.jpg';
        await repo.uploadPhotoBytes(
          date: widget.date,
          photoType: entry.key,
          bytes: bytes,
          filename: filename,
        );
        uploaded++;
      } catch (e) {
        // If the server says KYC is required, invalidate the cached status so
        // the photos screen re-evaluates the gate, then abort uploading.
        if (ErrorHandler.isKycRequired(e)) {
          ref.invalidate(kycStatusProvider);
          if (mounted) context.pop();
          return;
        }
        lastError = ErrorHandler.getErrorMessage(e);
      }
    }

    if (!mounted) return;

    if (lastError != null && uploaded == 0) {
      // All uploads failed — stay on screen and show error.
      setState(() => _isSaving = false);
      ErrorHandler.showSnackBar(context, lastError);
      return;
    }

    if (lastError != null) {
      // Partial success — show warning before popping.
      ErrorHandler.showSnackBar(
        context,
        'Some photos failed to upload.',
        isError: true,
      );
    }

    // Pop FIRST, then schedule provider invalidations for the next frame.
    // Calling ref.invalidate() and Navigator.pop() in the same synchronous
    // block schedules both a provider rebuild and a Navigator mutation for the
    // same frame, which can set _debugLocked while the Navigator is building
    // and trigger the !_debugLocked assertion.
    if (mounted) Navigator.of(context).pop();
    PaintingBinding.instance.imageCache.clear();
    // Defer invalidations so they never race with Navigator.pop().
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(photosByDateProvider(date));
      ref.invalidate(dashboardProvider);
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasAnySelected = _selected.isNotEmpty;
    final date = DateTime.parse(widget.date);
    final sessionAsync = ref.watch(photosByDateProvider(date));
    final existing = <String, ProgressPhoto>{};
    sessionAsync.whenData((session) {
      if (session != null) {
        for (final p in session.photos) {
          existing[p.photoType] = p;
        }
      }
    });
    final hasExisting = existing.isNotEmpty;

    return Scaffold(
      appBar: FitrackAppBar(
        title: DateFormat('MMM d, yyyy').format(DateTime.parse(widget.date)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose your photos',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap a slot to select a photo. You can add one or all three poses.',
                    style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 24),

                  // ── Pose slots ─────────────────────────────────────────
                  Row(
                    children: [
                      for (int i = 0; i < _photoTypes.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          child: _EditSlot(
                            label: _photoLabels[_photoTypes[i]]!,
                            previewBytes: _previewBytes[_photoTypes[i]],
                            existingPhoto: existing[_photoTypes[i]],
                            onTap: () => _showPicker(_photoTypes[i]),
                            onClear: _selected[_photoTypes[i]] != null
                                ? () => setState(() {
                                        _selected.remove(_photoTypes[i]);
                                        _previewBytes.remove(_photoTypes[i]);
                                      })
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // ── Current photos (read-only) ─────────────────────────
                  if (hasExisting) ...[
                    const SizedBox(height: 28),
                    const Text(
                      'Current Photos',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (int i = 0; i < _photoTypes.length; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(
                            child: _ReadOnlySlot(
                              label: _photoLabels[_photoTypes[i]]!,
                              photo: existing[_photoTypes[i]],
                              onTap: existing[_photoTypes[i]]?.imageUrl != null
                                  ? () => _openPreview(existing, i)
                                  : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Save bar ───────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
            decoration: const BoxDecoration(
              color: AppTheme.background,
              border: Border(top: BorderSide(color: AppTheme.divider)),
            ),
            child: AppButton(
              label: 'Save Photos',
              icon: LucideIcons.check,
              isLoading: _isSaving,
              onPressed: hasAnySelected && !_isSaving ? _save : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Editable slot ─────────────────────────────────────────────────────────────

class _EditSlot extends StatelessWidget {
  final String label;
  final Uint8List? previewBytes;
  final ProgressPhoto? existingPhoto;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _EditSlot({
    required this.label,
    required this.previewBytes,
    required this.existingPhoto,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasLocal = previewBytes != null;

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasLocal ? AppTheme.primary : AppTheme.divider,
              width: hasLocal ? 2 : 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Preview ──────────────────────────────────────────
              if (hasLocal)
                Image.memory(previewBytes!, fit: BoxFit.cover)
              else if (existingPhoto?.imageUrl != null)
                Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      existingPhoto!.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(LucideIcons.imageOff,
                            color: AppTheme.textMuted, size: 28),
                      ),
                    ),
                    Container(color: Colors.black.withValues(alpha: 0.35)),
                    const Center(
                      child: Icon(LucideIcons.pencil,
                          color: Colors.white, size: 22),
                    ),
                  ],
                )
              else
                const Center(
                  child: Icon(LucideIcons.plus,
                      color: AppTheme.textMuted, size: 28),
                ),

              // ── Label gradient overlay ────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (hasLocal) ...[
                        const SizedBox(width: 4),
                        const Icon(LucideIcons.check,
                            size: 11, color: AppTheme.primary),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Clear button (local selection only) ──────────────
              if (hasLocal && onClear != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: onClear,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(LucideIcons.x,
                          size: 14, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Read-only slot (current saved photo) ─────────────────────────────────────

class _ReadOnlySlot extends StatelessWidget {
  final String label;
  final ProgressPhoto? photo;
  final VoidCallback? onTap;

  const _ReadOnlySlot({required this.label, required this.photo, this.onTap});

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
          border: Border.all(color: AppTheme.divider, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo?.imageUrl != null)
              Image.network(
                photo!.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(LucideIcons.imageOff,
                      color: AppTheme.textMuted, size: 28),
                ),
              )
            else
              const Center(
                child: Icon(LucideIcons.imageMinus,
                    color: AppTheme.textMuted, size: 28),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
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
          ],
        ),
      ),
      ),
    );
  }
}

// ── Source picker button ──────────────────────────────────────────────────────

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
