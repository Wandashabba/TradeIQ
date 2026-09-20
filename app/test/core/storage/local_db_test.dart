import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';

void main() {
  test('enqueues a sync item and reads it back unsynced', () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);

    await db.enqueue(
      entityType: 'visit',
      entityId: 'visit-1',
      payloadJson: '{"outletId":"outlet-1"}',
    );

    final rows = await db.select(db.syncQueueItems).get();
    expect(rows, hasLength(1));
    expect(rows.first.synced, isFalse);
  });

  test('stores and reads back a stock draft', () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);

    await db
        .into(db.stockDrafts)
        .insert(
          StockDraftsCompanion.insert(
            id: 's1',
            visitDraftId: 'v1',
            skuId: 'sku1',
            unitsAvailable: const Value(20),
            lastStockinDate: DateTime(2026, 7, 1),
          ),
        );

    final rows = await db.select(db.stockDrafts).get();
    expect(rows, hasLength(1));
    expect(rows.first.skuId, 'sku1');
    expect(rows.first.visitDraftId, 'v1');
    expect(rows.first.unitsAvailable, 20);
  });

  test('keeps an uncounted SKU null rather than storing it as zero', () async {
    // #389. The column used to be NOT NULL, so a SKU the agent had not reached
    // could only be stored as 0 — and 0 is a finding: it raises a stock-out
    // task and drags on-shelf availability down for a shelf nobody looked at.
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);

    await db
        .into(db.stockDrafts)
        .insert(
          StockDraftsCompanion.insert(
            id: 's2',
            visitDraftId: 'v1',
            skuId: 'sku2',
            lastStockinDate: DateTime(2026, 7, 1),
          ),
        );

    final rows = await db.select(db.stockDrafts).get();
    expect(rows.single.unitsAvailable, isNull);
  });

  group('decoded payload size (#382)', () {
    test('measures a plain JSON row as its real UTF-8 byte length', () {
      const payload = '{"visitId":"v1","note":"café"}';
      // "café" is five bytes in UTF-8, not four characters' worth — the outbox
      // reports storage, so it has to count bytes rather than code units.
      expect(decodedPayloadBytes(payload), utf8.encode(payload).length);
      expect(decodedPayloadBytes(payload), payload.length + 1);
    });

    test('reports a photo at its decoded size, not its base64 length', () {
      // The bug this exists to prevent: base64 inflates by 4/3, so a 3 MB photo
      // reported at its stored length reads as 4 MB. An agent told to clear 4 MB
      // of queue would free 3.
      final image = List<int>.generate(3000, (i) => i % 256);
      final encoded = base64Encode(image);
      final payload = '{"dataUrl":"data:image/jpeg;base64,$encoded"}';

      expect(encoded.length, greaterThan(image.length));
      final measured = decodedPayloadBytes(payload);
      // The row's own JSON scaffolding plus the image's REAL bytes.
      expect(measured, (payload.length - encoded.length) + image.length);
      expect(measured, lessThan(utf8.encode(payload).length));
    });

    test('stamps the size on the row at enqueue', () async {
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);

      const payload = '{"skuId":"s1"}';
      await db.enqueue(
        entityType: 'stock',
        entityId: 'e1',
        payloadJson: payload,
      );

      final row = await db.select(db.syncQueueItems).getSingle();
      expect(row.payloadBytes, decodedPayloadBytes(payload));
    });
  });
}
