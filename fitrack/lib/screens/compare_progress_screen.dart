import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:before_after/before_after.dart';
import '../repositories/tracker_repository.dart';
import '../widgets/app_bar.dart';

class CompareProgressScreen extends ConsumerStatefulWidget {
  const CompareProgressScreen({super.key});

  @override
  ConsumerState<CompareProgressScreen> createState() => _CompareProgressScreenState();
}

class _CompareProgressScreenState extends ConsumerState<CompareProgressScreen> {
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  String _selectedType = 'FRONT';
  
  Map<String, String?> _images = {'from_image': null, 'to_image': null};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchComparison();
  }

  Future<void> _fetchComparison() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(trackerRepositoryProvider);
      final fromStr = DateFormat('yyyy-MM-dd').format(_fromDate);
      final toStr = DateFormat('yyyy-MM-dd').format(_toDate);
      
      final result = await repo.comparePhotos(
        fromDate: fromStr,
        toDate: toStr,
        type: _selectedType,
      );
      
      if (mounted) {
        setState(() {
          _images = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final initialDate = isFrom ? _fromDate : _toDate;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (date != null) {
      setState(() {
        if (isFrom) {
          _fromDate = date;
          if (_fromDate.isAfter(_toDate)) {
            _toDate = _fromDate.add(const Duration(days: 1));
          }
        } else {
          _toDate = date;
          if (_toDate.isBefore(_fromDate)) {
            _fromDate = _toDate.subtract(const Duration(days: 1));
          }
        }
      });
      _fetchComparison();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FitrackAppBar(title: 'Compare'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () => _pickDate(true),
                  child: Text(
                    DateFormat('MMM d, yyyy').format(_fromDate),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Icon(LucideIcons.arrowRightLeft, color: Color(0xFF94A3B8), size: 16),
                GestureDetector(
                  onTap: () => _pickDate(false),
                  child: Text(
                    DateFormat('MMM d, yyyy').format(_toDate),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'FRONT', label: Text('Front')),
              ButtonSegment(value: 'SIDE', label: Text('Side')),
              ButtonSegment(value: 'BACK', label: Text('Back')),
            ],
            selected: {_selectedType},
            onSelectionChanged: (set) {
              setState(() => _selectedType = set.first);
              _fetchComparison();
            },
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.resolveWith<Color>((states) => states.contains(MaterialState.selected) ? const Color(0xFF22C55E) : const Color(0xFF111111)),
              foregroundColor: MaterialStateProperty.resolveWith<Color>((states) => states.contains(MaterialState.selected) ? Colors.white : const Color(0xFF94A3B8)),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF22C55E)))
              : (_images['from_image'] != null && _images['to_image'] != null)
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BeforeAfter(
                        before: CachedNetworkImage(imageUrl: _images['from_image']!, fit: BoxFit.cover),
                        after: CachedNetworkImage(imageUrl: _images['to_image']!, fit: BoxFit.cover),
                        thumbColor: const Color(0xFF22C55E),
                        trackColor: Colors.white,
                      ),
                    ),
                  )
                : const Center(
                    child: Text('Missing photos for one or both dates.', style: TextStyle(color: Color(0xFF94A3B8))),
                  ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
