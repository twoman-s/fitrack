import 'package:flutter_riverpod/flutter_riverpod.dart';

class NavState {
  final int current;
  final int previous;
  NavState({required this.current, required this.previous});
}

class NavNotifier extends Notifier<NavState> {
  @override
  NavState build() => NavState(current: 0, previous: 0);

  void updateIndex(int newIndex) {
    if (state.current == newIndex) return;
    state = NavState(current: newIndex, previous: state.current);
  }
}

final navStateProvider = NotifierProvider<NavNotifier, NavState>(NavNotifier.new);
