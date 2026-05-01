import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/error_handler.dart';
import '../core/theme.dart';
import '../models/dashboard.dart';
import '../providers/dashboard_provider.dart';
import '../repositories/tracker_repository.dart';
import '../widgets/app_bar.dart';
import '../widgets/app_button.dart';
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
  /// Locally selected files (XFile), keyed by photo type. Not yet uploaded.
  final Map<String, XFile> _selected = {};

  /// Preloaded bytes for preview, keyed by photo type.
  final Map<String, Uint8List> _previewBytes = {};

  /// Existing server photos for this date, keyed by photo type.
  final Map<String, ProgressPhoto> _existing = {};

  bool _isSaving = false;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  /// Pre-populate slots from provider cache if the session already has photos.
  void _loadExisting() {
    final date = DateTime.parse(widget.date);
    final session = ref
        .read(photosByDateProvider(date))
        .valueOrNull;
    if (session != null) {
      for (final p in session.photos) {
        _existing[p.photoType] = p;
      }
    }
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
      _selected[photoType] = picked;
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
      final xFile = await Navigator.of(context, rootNavigator: true).push<XFile>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => InAppCameraScreen(photoType: photoType),
        ),
      );
      if (xFile == null || !mounted) return;
      final bytes = await xFile.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selected[photoType] = xFile;
        _previewBytes[photoType] = bytes;
      });
    } else {
      await _pick(photoType, source);
    }
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
        lastError = e is Exception ? e.toString() : 'Upload failed for ${_photoLabels[entry.key]}.';
      }
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (lastError != null && uploaded == 0) {
      ErrorHandler.showSnackBar(context, lastError);
      return;
    }

    // Invalidate providers so photos screen refreshes.
    final date = DateTime.parse(widget.date);
    ref.invalidate(photosByDateProvider(date));
    ref.invalidate(dashboardProvider);

    if (lastError != null) {
      // Partial success — show warning then pop.
      ErrorHandler.showSnackBar(
        context,
        'Some photos failed to upload.',
        isError: true,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasAnySelected = _selected.isNotEmpty;

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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _photoTypes.asMap().entries.map((entry) {
                      final i = entry.key;
                      final type = entry.value;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: i == 0 ? 0 : 6,
                            right: i == _photoTypes.length - 1 ? 0 : 6,
                          ),
                          child: _EditSlot(
                            label: _photoLabels[type]!,
                            previewBytes: _previewBytes[type],
                            existingPhoto: _existing[type],
                            onTap: () => _showPicker(type),
                            onClear: _selected[type] != null
                                ? () => setState(() {
                                        _selected.remove(type);
                                        _previewBytes.remove(type);
                                      })
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
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

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasLocal
                      ? AppTheme.primary
                      : AppTheme.divider,
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
                        // Dim to indicate it will be replaced on tap
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
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (hasLocal) ...[
              const SizedBox(width: 4),
              const Icon(LucideIcons.check,
                  size: 12, color: AppTheme.primary),
            ],
          ],
        ),
      ],
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
