import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../repositories/tracker_repository.dart';
import '../models/weight.dart';
import '../widgets/daily_weight_card.dart';
import '../widgets/app_bar.dart';
import '../widgets/app_button.dart';

class WeightHistoryFilters {
  final DateTime? startDate;
  final DateTime? endDate;
  final int? month;
  final int? year;

  WeightHistoryFilters({
    this.startDate,
    this.endDate,
    this.month,
    this.year,
  });

  WeightHistoryFilters copyWith({
    DateTime? startDate,
    DateTime? endDate,
    int? month,
    int? year,
    bool clearDates = false,
    bool clearMonthYear = false,
  }) {
    return WeightHistoryFilters(
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      month: clearMonthYear ? null : (month ?? this.month),
      year: clearMonthYear ? null : (year ?? this.year),
    );
  }

  bool get isEmpty => startDate == null && endDate == null && month == null && year == null;
}

class WeightHistoryState {
  final List<WeightEntry> entries;
  final bool isLoading;
  final bool isFetchingMore;
  final bool hasMore;
  final int offset;
  final WeightHistoryFilters filters;

  WeightHistoryState({
    this.entries = const [],
    this.isLoading = true,
    this.isFetchingMore = false,
    this.hasMore = true,
    this.offset = 0,
    required this.filters,
  });

  WeightHistoryState copyWith({
    List<WeightEntry>? entries,
    bool? isLoading,
    bool? isFetchingMore,
    bool? hasMore,
    int? offset,
    WeightHistoryFilters? filters,
  }) {
    return WeightHistoryState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      isFetchingMore: isFetchingMore ?? this.isFetchingMore,
      hasMore: hasMore ?? this.hasMore,
      offset: offset ?? this.offset,
      filters: filters ?? this.filters,
    );
  }
}

class WeightHistoryNotifier extends StateNotifier<WeightHistoryState> {
  final TrackerRepository _repo;
  static const int _limit = 30;

  WeightHistoryNotifier(this._repo) : super(WeightHistoryState(filters: WeightHistoryFilters())) {
    fetchInitial();
  }

  Future<void> fetchInitial() async {
    state = state.copyWith(isLoading: true, entries: [], offset: 0, hasMore: true);
    try {
      final response = await _repo.getPaginatedWeights(
        limit: _limit,
        offset: 0,
        startDate: state.filters.startDate != null ? DateFormat('yyyy-MM-dd').format(state.filters.startDate!) : null,
        endDate: state.filters.endDate != null ? DateFormat('yyyy-MM-dd').format(state.filters.endDate!) : null,
        month: state.filters.month,
        year: state.filters.year,
      );
      state = state.copyWith(
        isLoading: false,
        entries: response.results,
        offset: response.results.length,
        hasMore: response.next != null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> fetchMore() async {
    if (state.isFetchingMore || !state.hasMore) return;

    state = state.copyWith(isFetchingMore: true);
    try {
      final response = await _repo.getPaginatedWeights(
        limit: _limit,
        offset: state.offset,
        startDate: state.filters.startDate != null ? DateFormat('yyyy-MM-dd').format(state.filters.startDate!) : null,
        endDate: state.filters.endDate != null ? DateFormat('yyyy-MM-dd').format(state.filters.endDate!) : null,
        month: state.filters.month,
        year: state.filters.year,
      );
      state = state.copyWith(
        isFetchingMore: false,
        entries: [...state.entries, ...response.results],
        offset: state.offset + response.results.length,
        hasMore: response.next != null,
      );
    } catch (e) {
      state = state.copyWith(isFetchingMore: false);
    }
  }

  void updateFilters(WeightHistoryFilters filters) {
    state = state.copyWith(filters: filters);
    fetchInitial();
  }

  void clearFilters() {
    state = state.copyWith(filters: WeightHistoryFilters());
    fetchInitial();
  }
}

final weightHistoryProvider = StateNotifierProvider.autoDispose<WeightHistoryNotifier, WeightHistoryState>((ref) {
  final repo = ref.watch(trackerRepositoryProvider);
  return WeightHistoryNotifier(repo);
});

class WeightHistoryScreen extends ConsumerStatefulWidget {
  const WeightHistoryScreen({super.key});

  @override
  ConsumerState<WeightHistoryScreen> createState() => _WeightHistoryScreenState();
}

class _WeightHistoryScreenState extends ConsumerState<WeightHistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(weightHistoryProvider.notifier).fetchMore();
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const FilterBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(weightHistoryProvider);

    return Scaffold(
      appBar: FitrackAppBar(
        title: 'History',
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(LucideIcons.filter),
                if (!history.filters.isEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                    ),
                  ),
              ],
            ),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: history.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF22C55E)))
          : history.entries.isEmpty
              ? _buildEmptyState(history.filters.isEmpty)
              : RefreshIndicator(
                  color: const Color(0xFF22C55E),
                  onRefresh: () async => ref.read(weightHistoryProvider.notifier).fetchInitial(),
                  child: Column(
                    children: [
                      if (!history.filters.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.filter, size: 14, color: Color(0xFF22C55E)),
                              const SizedBox(width: 8),
                              const Text(
                                'Filtered View',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              ),
                              const Spacer(),
                              AppButton.ghost(
                                label: 'Clear All',
                                compact: true,
                                onPressed: () => ref.read(weightHistoryProvider.notifier).clearFilters(),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: history.entries.length + (history.hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == history.entries.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(child: CircularProgressIndicator(color: Color(0xFF22C55E))),
                              );
                            }

                            final entry = history.entries[index];
                            return DailyWeightCard(
                              date: entry.date,
                              morningWeight: entry.morningWeight,
                              morningWeightTime: entry.morningWeightTime,
                              eveningWeight: entry.eveningWeight,
                              eveningWeightTime: entry.eveningWeightTime,
                              onTap: () {
                                context.push('/add-weight', extra: entry).then((_) {
                                  ref.read(weightHistoryProvider.notifier).fetchInitial();
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-weight').then((_) => ref.read(weightHistoryProvider.notifier).fetchInitial()),
        backgroundColor: const Color(0xFF22C55E),
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(bool noFilters) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.clipboardList, size: 64, color: Color(0xFF1A1A1A)),
          const SizedBox(height: 16),
          Text(
            noFilters ? 'No weight entries found.' : 'No entries match your filters.',
            style: const TextStyle(color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 24),
          if (noFilters)
            AppButton(
              label: 'Log Weight',
              icon: LucideIcons.plus,
              onPressed: () => context.push('/add-weight').then((_) => ref.read(weightHistoryProvider.notifier).fetchInitial()),
            )
          else
            AppButton.ghost(
              label: 'Clear Filters',
              onPressed: () => ref.read(weightHistoryProvider.notifier).clearFilters(),
            ),
        ],
      ),
    );
  }
}

class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  late WeightHistoryFilters _tempFilters;

  @override
  void initState() {
    super.initState();
    _tempFilters = ref.read(weightHistoryProvider).filters;
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: _tempFilters.startDate != null && _tempFilters.endDate != null
          ? DateTimeRange(start: _tempFilters.startDate!, end: _tempFilters.endDate!)
          : null,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF22C55E),
              surface: Color(0xFF111111),
            ),
          ),
          child: child!,
        );
      },
    );

    if (range != null) {
      setState(() {
        _tempFilters = _tempFilters.copyWith(
          startDate: range.start,
          endDate: range.end,
          clearMonthYear: true,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filter History',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              AppButton.ghost(
                label: 'Reset',
                color: Colors.redAccent,
                onPressed: () {
                  ref.read(weightHistoryProvider.notifier).clearFilters();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Date Range Filter
          const Text('Date Range', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDateRange,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.calendar, size: 20, color: Color(0xFF22C55E)),
                  const SizedBox(width: 12),
                  Text(
                    _tempFilters.startDate != null && _tempFilters.endDate != null
                        ? '${DateFormat('MMM d').format(_tempFilters.startDate!)} - ${DateFormat('MMM d').format(_tempFilters.endDate!)}'
                        : 'Select Date Range',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const Spacer(),
                  const Icon(LucideIcons.chevronRight, size: 20, color: Color(0xFF4B5563)),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Month/Year Filter
          const Text('Specific Month', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DropdownField<int>(
                  value: _tempFilters.month,
                  items: List.generate(12, (i) => i + 1),
                  label: 'Month',
                  itemLabel: (m) => DateFormat('MMMM').format(DateTime(2024, m)),
                  onChanged: (val) {
                    setState(() {
                      _tempFilters = _tempFilters.copyWith(month: val, clearDates: true);
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DropdownField<int>(
                  value: _tempFilters.year,
                  items: List.generate(5, (i) => DateTime.now().year - i),
                  label: 'Year',
                  itemLabel: (y) => y.toString(),
                  onChanged: (val) {
                    setState(() {
                      _tempFilters = _tempFilters.copyWith(year: val, clearDates: true);
                    });
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          AppButton(
            label: 'Apply Filters',
            onPressed: () {
              ref.read(weightHistoryProvider.notifier).updateFilters(_tempFilters);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final T? value;
  final List<T> items;
  final String label;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.value,
    required this.items,
    required this.label,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(label, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 14)),
          dropdownColor: const Color(0xFF1A1A1A),
          icon: const Icon(LucideIcons.chevronDown, size: 16, color: Color(0xFF4B5563)),
          items: [
            DropdownMenuItem<T>(value: null, child: Text('All $label')),
            ...items.map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(itemLabel(item), style: const TextStyle(color: Colors.white, fontSize: 14)),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
