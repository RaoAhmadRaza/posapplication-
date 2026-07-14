import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_app/features/dashboard/presentation/controllers/kpi_layout_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('KPI layout hide + reorder survives a simulated app restart', () async {
    SharedPreferences.setMockInitialValues({});

    // First "session": load defaults, hide one card, move another to the front.
    final session1 = ProviderContainer();
    addTearDown(session1.dispose);
    await session1.read(kpiLayoutProvider.future);
    final ctrl = session1.read(kpiLayoutProvider.notifier);
    await ctrl.toggle('payables'); // hide
    await ctrl.move(5, 0); // reorder: move index 5 to the front
    final expected = session1.read(kpiLayoutProvider).value!;

    // Second "session": a fresh container reads persisted shared_preferences
    // — this is what happens after the app is killed and relaunched.
    final session2 = ProviderContainer();
    addTearDown(session2.dispose);
    final reloaded = await session2.read(kpiLayoutProvider.future);

    expect(
      reloaded.map((p) => '${p.key}:${p.visible}').toList(),
      expected.map((p) => '${p.key}:${p.visible}').toList(),
      reason: 'order + visibility must match the persisted layout',
    );
    expect(
      reloaded.firstWhere((p) => p.key == 'payables').visible,
      isFalse,
      reason: 'hidden card stays hidden after restart',
    );
    // All 10 canonical keys still present (forward-compat append).
    expect(reloaded.length, kpiKeysDefault.length);
  });
}
