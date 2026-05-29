import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Set of `Branch.fullName` values that are CURRENTLY HIDDEN.
/// We invert (track hidden, not visible) so that fresh repos default to
/// "everything visible" without needing to pre-populate.
class HiddenRefsNotifier extends StateNotifier<Set<String>> {
  HiddenRefsNotifier() : super(<String>{});

  void toggle(String fullName) {
    final next = Set<String>.from(state);
    if (!next.add(fullName)) next.remove(fullName);
    state = next;
  }

  void clear() {
    state = <String>{};
  }

  bool isHidden(String fullName) => state.contains(fullName);
}

final hiddenRefsProvider =
    StateNotifierProvider<HiddenRefsNotifier, Set<String>>((ref) {
  return HiddenRefsNotifier();
});

/// `Branch.fullName` of the ref currently selected in the sidebar, so the row
/// can render a selection highlight. Null when nothing is selected.
final selectedSidebarRefProvider = StateProvider<String?>((_) => null);
