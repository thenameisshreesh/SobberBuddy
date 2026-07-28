import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks shell tab activations so tab screens can refresh when they regain focus.
class ShellTabState {
  const ShellTabState({required this.activeTab, required this.generation});

  final String activeTab;
  final int generation;
}

class ShellTabNotifier extends Notifier<ShellTabState> {
  static const shellTabs = {'/home', '/history', '/profile'};

  @override
  ShellTabState build() => const ShellTabState(activeTab: '/home', generation: 0);

  void activateTab(String tab) {
    if (!shellTabs.contains(tab)) return;
    state = ShellTabState(
      activeTab: tab,
      generation: state.generation + 1,
    );
  }
}

final shellTabNotifierProvider =
    NotifierProvider<ShellTabNotifier, ShellTabState>(ShellTabNotifier.new);
