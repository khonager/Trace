import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/policy/user_selection_policy.dart';

void main() {
  test('everyone-except excludes listed Matrix users', () {
    const policy = UserSelectionPolicy(
      enabled: true,
      mode: UserSelectionMode.everyoneExcept,
      userIds: {'@work:example.org'},
    );

    expect(policy.allows('@friend:example.org'), isTrue);
    expect(policy.allows('@work:example.org'), isFalse);
  });

  test('only includes listed Matrix users', () {
    const policy = UserSelectionPolicy(
      enabled: true,
      mode: UserSelectionMode.only,
      userIds: {'@friend:example.org'},
    );

    expect(policy.allows('@friend:example.org'), isTrue);
    expect(policy.allows('@stranger:example.org'), isFalse);
  });

  test('disabled never selects a recipient', () {
    const policy = UserSelectionPolicy.disabled();

    expect(policy.allows('@friend:example.org'), isFalse);
  });
}
