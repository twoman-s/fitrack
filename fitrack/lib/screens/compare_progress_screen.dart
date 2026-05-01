import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme.dart';
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
                      child: _ComparisonSlider(
                        beforeUrl: _images['from_image']!,
                        afterUrl: _images['to_image']!,
                        beforeLabel: DateFormat('MMM d').format(_fromDate),
                        afterLabel: DateFormat('MMM d').format(_toDate),
                      ),
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.imageMinus, color: AppTheme.textMuted, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'No photos found for one or both dates.',
                          style: TextStyle(color: AppTheme.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Custom comparison slider ───────────────────────────────────────────────────

class _ComparisonSlider extends StatefulWidget {
  final String beforeUrl;
  final String afterUrl;
  final String beforeLabel;
  final String afterLabel;

  const _ComparisonSlider({
    required this.beforeUrl,
    required this.afterUrl,
    required this.beforeLabel,
    required this.afterLabel,
  });

  @override
  State<_ComparisonSlider> createState() => _ComparisonSliderState();
}

class _ComparisonSliderState extends State<_ComparisonSlider> {
  double _position = 0.5; // 0.0 = all before, 1.0 = all after

  void _onDrag(DragUpdateDetails details, double width) {
    setState(() {
      _position = (_position + details.delta.dx / width).clamp(0.02, 0.98);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final dividerX = w * _position;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (d) => _onDrag(d, w),
          onTapDown: (d) => setState(() {
            _position = (d.localPosition.dx / w).clamp(0.02, 0.98);
          }),
          child: Stack(
            children: [
              // ── "After" image (full width, behind) ────────────────────
              SizedBox.expand(
                child: Image.network(
                  widget.afterUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(color: AppTheme.surface),
                ),
              ),

              // ── "Before" image (clipped to left of divider) ───────────
              ClipRect(
                clipper: _LeftClipper(dividerX),
                child: SizedBox(
                  width: w,
                  height: h,
                  child: Image.network(
                    widget.beforeUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(color: AppTheme.surface),
                  ),
                ),
              ),

              // ── Divider line ──────────────────────────────────────────
              Positioned(
                left: dividerX - 1,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  color: Colors.white,
                ),
              ),

              // ── Drag handle ───────────────────────────────────────────
              Positioned(
                left: dividerX - 20,
                top: h / 2 - 20,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.swap_horiz,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),

              // ── "Before" label ────────────────────────────────────────
              Positioned(
                left: 12,
                bottom: 12,
                child: _Label(widget.beforeLabel),
              ),

              // ── "After" label ─────────────────────────────────────────
              Positioned(
                right: 12,
                bottom: 12,
                child: _Label(widget.afterLabel),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  final double dividerX;
  const _LeftClipper(this.dividerX);

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, dividerX, size.height);

  @override
  bool shouldReclip(_LeftClipper old) => old.dividerX != dividerX;
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
