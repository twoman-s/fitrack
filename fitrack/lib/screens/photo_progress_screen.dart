import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../repositories/tracker_repository.dart';
import '../models/dashboard.dart';
import '../widgets/app_bar.dart';
import '../widgets/app_button.dart';

final photosByDateProvider = FutureProvider.family<PhotoSession?, DateTime>((ref, date) async {
  final repo = ref.watch(trackerRepositoryProvider);
  final dateStr = DateFormat('yyyy-MM-dd').format(date);
  try {
    return await repo.getPhotosByDate(dateStr);
  } catch (e) {
    return null; // No photos for this date
  }
});

class PhotoProgressScreen extends ConsumerStatefulWidget {
  const PhotoProgressScreen({super.key});

  @override
  ConsumerState<PhotoProgressScreen> createState() => _PhotoProgressScreenState();
}

class _PhotoProgressScreenState extends ConsumerState<PhotoProgressScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(photosByDateProvider(_selectedDate));

    return Scaffold(
      appBar: FitrackAppBar(
        title: 'Photos',
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.arrowLeftRight),
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
                color: Color(0xFF22C55E),
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Color(0xFF1A1A1A),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Divider(color: Color(0xFF1A1A1A), height: 1),
          Expanded(
            child: sessionAsync.when(
              data: (session) {
                if (session == null || session.photos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.cameraOff, size: 64, color: Color(0xFF1A1A1A)),
                        const SizedBox(height: 16),
                        const Text('No photos for this date', style: TextStyle(color: Color(0xFF94A3B8))),
                        const SizedBox(height: 24),
                        AppButton(
                          label: 'Add Photos',
                          icon: LucideIcons.plus,
                          onPressed: () => context.push('/upload-photo'),
                        ),
                      ],
                    ),
                  );
                }

                // Map photos by type
                final photoMap = {
                  for (var p in session.photos) p.photoType: p.imageUrl
                };

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 84),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('MMMM d, yyyy').format(_selectedDate),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(child: _PhotoCard(title: 'Front', url: photoMap['FRONT'])),
                          const SizedBox(width: 12),
                          Expanded(child: _PhotoCard(title: 'Side', url: photoMap['SIDE'])),
                          const SizedBox(width: 12),
                          Expanded(child: _PhotoCard(title: 'Back', url: photoMap['BACK'])),
                        ],
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF22C55E))),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),

    );
  }
}

class _PhotoCard extends StatelessWidget {
  final String title;
  final String? url;

  const _PhotoCard({required this.title, this.url});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 3/4,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: url != null
                ? CachedNetworkImage(
                    imageUrl: url!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    errorWidget: (context, url, error) => const Icon(LucideIcons.imageOff, color: Color(0xFF94A3B8)),
                  )
                : const Icon(LucideIcons.user, size: 48, color: Color(0xFF1A1A1A)),
          ),
        ),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
      ],
    );
  }
}
