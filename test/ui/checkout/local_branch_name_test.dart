import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/ui/checkout/safe_checkout.dart';

void main() {
  test('localBranchNameFor strips exactly the remote segment', () {
    expect(localBranchNameFor('origin/main'), 'main');
    expect(localBranchNameFor('origin/feat/nested/x'), 'feat/nested/x');
    expect(localBranchNameFor('upstream/release/1.2'), 'release/1.2');
  });
}
