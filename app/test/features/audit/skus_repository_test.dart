import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/audit/data/skus_repository.dart';

class _FakeSkusRepository implements SkusRepository {
  @override
  Future<List<Sku>> listSkus() async => const [
        Sku(id: 's1', name: 'Test Cola', category: 'Beverages', minFacingsStandard: 4, rrp: 19.99),
      ];
}

void main() {
  test('skusListProvider resolves the repository result', () async {
    final container = ProviderContainer(
      overrides: [skusRepositoryProvider.overrideWithValue(_FakeSkusRepository())],
    );
    addTearDown(container.dispose);

    final skus = await container.read(skusListProvider.future);

    expect(skus, hasLength(1));
    expect(skus.first.name, 'Test Cola');
  });

  test('Sku.fromJson parses numeric fields', () {
    final sku = Sku.fromJson({
      'id': 's2',
      'name': 'Water 1L',
      'category': 'Beverages',
      'minFacingsStandard': 3,
      'rrp': 12.5,
    });
    expect(sku.minFacingsStandard, 3);
    expect(sku.rrp, 12.5);
  });
}
