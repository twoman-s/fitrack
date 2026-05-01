import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../repositories/tracker_repository.dart';
import '../providers/dashboard_provider.dart';
import '../core/error_handler.dart';
import 'photo_progress_screen.dart';
import '../widgets/app_bar.dart';
import '../widgets/app_button.dart';

class UploadPhotoScreen extends ConsumerStatefulWidget {
  const UploadPhotoScreen({super.key});

  @override
  ConsumerState<UploadPhotoScreen> createState() => _UploadPhotoScreenState();
}

class _UploadPhotoScreenState extends ConsumerState<UploadPhotoScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedType = 'FRONT';
  File? _imageFile;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      ErrorHandler.showSnackBar(context, 'Failed to pick image.');
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null) {
      ErrorHandler.showSnackBar(context, 'Please select an image first.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(trackerRepositoryProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      await repo.uploadPhoto(
        date: dateStr,
        photoType: _selectedType,
        filePath: _imageFile!.path,
      );

      // Refresh providers
      ref.invalidate(dashboardProvider);
      ref.invalidate(photosByDateProvider(_selectedDate));

      if (mounted) {
        ErrorHandler.showSnackBar(context, 'Photo uploaded successfully!', isError: false);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showSnackBar(context, ErrorHandler.getErrorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FitrackAppBar(title: 'Take Photo'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date Picker
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) setState(() => _selectedDate = date);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(LucideIcons.calendar, color: Color(0xFF22C55E)),
                    Text(
                      DateFormat('MMMM d, yyyy').format(_selectedDate),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Icon(LucideIcons.chevronRight, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Type Selector
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'FRONT', label: Text('Front')),
                ButtonSegment(value: 'SIDE', label: Text('Side')),
                ButtonSegment(value: 'BACK', label: Text('Back')),
              ],
              selected: {_selectedType},
              onSelectionChanged: (set) {
                setState(() => _selectedType = set.first);
              },
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.resolveWith<Color>(
                  (states) {
                    if (states.contains(MaterialState.selected)) {
                      return const Color(0xFF22C55E);
                    }
                    return const Color(0xFF111111);
                  },
                ),
                foregroundColor: MaterialStateProperty.resolveWith<Color>(
                  (states) {
                    if (states.contains(MaterialState.selected)) {
                      return Colors.white;
                    }
                    return const Color(0xFF94A3B8);
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Image Preview Area
            AspectRatio(
              aspectRatio: 3/4,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: _imageFile != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(_imageFile!, fit: BoxFit.cover),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(LucideIcons.xCircle, color: Colors.white, size: 32),
                              onPressed: () => setState(() => _imageFile = null),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.user, size: 80, color: const Color(0xFF1A1A1A).withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          const Text('Position yourself in the frame', style: TextStyle(color: Color(0xFF94A3B8))),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),

            // Action Buttons
            if (_imageFile == null) ...[
              Row(
                children: [
                  Expanded(
                    child: AppButton.outlined(
                      label: 'Gallery',
                      icon: LucideIcons.image,
                      color: const Color(0xFF4B5563),
                      onPressed: () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AppButton(
                      label: 'Camera',
                      icon: LucideIcons.camera,
                      onPressed: () => _pickImage(ImageSource.camera),
                    ),
                  ),
                ],
              ),
            ] else ...[
              AppButton(
                label: 'Upload Photo',
                isLoading: _isLoading,
                onPressed: _uploadImage,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
