import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/audit/data/skus_repository.dart';

class _FakeSkusRepository implements SkusRepository {
  String? receivedOutletId;

  @override
  Future<List<Sku>> listSkus({required String outletId}) async {
    receivedOutletId = outletId;
    return const [
      Sku(id: 's1', name: 'Test Cola', category: 'Beverages', minFacingsStandard: 4, rrp: 19.99,
          daysOutOfStock: 2, velocityAvg: 3.5),
    ];
  }
}

void main() {
  test('skusListProvider resolves the repository result for the given outlet', () async {
    final fake = _FakeSkusRepository();
    final container = ProviderContainer(
      overrides: [skusRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final skus = await container.read(skusListProvider('outlet-1').future);

    expect(skus, hasLength(1));
    expect(skus.first.name, 'Test Cola');
    expect(skus.first.daysOutOfStock, 2);
    expect(skus.first.velocityAvg, 3.5);
    expect(fake.receivedOutletId, 'outlet-1');
  });

  test('Sku.fromJson parses numeric fields', () {
    final sku = Sku.fromJson({
      'id': 's2', 'name': 'Water 1L', 'category': 'Beverages',
      'minFacingsStandard': 3, 'rrp': 12.5, 'daysOutOfStock': 1, 'velocityAvg': 6.0,
    });
    expect(sku.minFacingsStandard, 3);
    expect(sku.rrp, 12.5);
    expect(sku.daysOutOfStock, 1);
    expect(sku.velocityAvg, 6.0);
  });
}
