import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/features/audit/data/skus_repository.dart';
import 'package:tradeiq_app/features/audit/data/template_section_repository.dart';
import 'package:tradeiq_app/features/audit/data/visit_progress.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

// The submit gate and the client-questions section (#122).
class _NoSkus implements SkusRepository {
  @override
  Future<PaginatedResponse<Sku>> listSkus({
    required String outletId,
    int? limit,
    String? cursor,
  }) async => const PaginatedResponse(data: [], nextCursor: null);
}

Map<String, Object?> _schema({bool required = true}) => {
  'sections': [
    {
      'id': 'promo',
      'fields': [
        {'id': 'facings', 'label': 'Facings', 'type': 'number', 'required': required},
        {'id': 'note', 'label': 'Note', 'type': 'text'},
      ],
    },
  ],
};

void main() {
  late LocalDb db;
  late ProviderContainer container;
  var queued = 0;

  setUp(() {
    currentLocalUserId = 'agent-a';
    db = LocalDb(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        localDbProvider.overrideWithValue(db),
        skusRepositoryProvider.overrideWithValue(_NoSkus()),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    currentLocalUserId = null;
  });

  Future<void> enqueue(String type, Map<String, Object?> payload) => db.enqueue(
    entityType: type,
    entityId: '$type-${queued++}',
    payloadJson: jsonEncode(payload),
  );

  Future<void> finishFixedRequired() async {
    for (final type in ['stock', 'visibility', 'pricing', 'capability']) {
      await enqueue(type, {'visitDraftId': 'v1', 'items': <Object>[]});
    }
  }

  Future<void> pin({bool required = true}) => db
      .into(db.pinnedVisitTemplates)
      .insert(
        PinnedVisitTemplatesCompanion.insert(
          visitDraftId: 'v1',
          templateId: const Value('tpl-1'),
          templateName: const Value('Promo Check'),
          templateVersion: const Value(3),
          schemaJson: Value(jsonEncode(_schema(required: required))),
        ),
      );

  Future<void> saveAnswers(Map<String, Object?> answers) => enqueue(
    templateResponseEntityType,
    {'visitDraftId': 'v1', 'templateId': 'tpl-1', 'templateVersion': 3, 'answers': answers},
  );

  /// Listens like a widget does, and waits until the template read has landed
  /// — the progress stream emits before and after it.
  Future<VisitProgress> progress() async {
    final skus = container.listen(skusListProvider('ou1'), (_, _) {}, fireImmediately: true);
    final tpl = container.listen(visitTemplateProvider('v1'), (_, _) {}, fireImmediately: true);
    await container.read(skusListProvider('ou1').future);
    await container.read(visitTemplateProvider('v1').future);

    final completer = Completer<VisitProgress>();
    final sub = container.listen<AsyncValue<VisitProgress>>(
      visitProgressProvider((visitDraftId: 'v1', outletId: 'ou1')),
      (_, next) {
        final value = next.value;
        final ready = container.read(visitTemplateProvider('v1')).hasValue;
        if (value != null && ready && !completer.isCompleted) {
          completer.complete(value);
        }
      },
      fireImmediately: true,
    );
    final value = await completer.future;
    sub.close();
    tpl.close();
    skus.close();
    return value;
  }

  test('no template: the progress is exactly the fixed audit', () async {
    await finishFixedRequired();
    final p = await progress();

    expect(p.template, isNull);
    expect(p.captureCount, 7);
    expect(p.blockingCount, 0);
    expect(p.canSubmit, isTrue);
  });

  test('required client questions never saved block the submit', () async {
    await pin();
    await finishFixedRequired();
    final p = await progress();

    expect(p.template, isNotNull);
    expect(p.template!.state, SectionState.notStarted);
    expect(p.blocking, isEmpty); // the fixed sections are all done…
    expect(p.templateBlocking, isTrue); // …but the client's questions are not
    expect(p.blockingCount, 1);
    expect(p.canSubmit, isFalse);
    expect(p.captureCount, 8); // the 7 fixed captures + the client's section
  });

  test('saved with a required answer missing is partial, and still blocks', () async {
    await pin();
    await finishFixedRequired();
    await saveAnswers({'note': 'hello'});
    final p = await progress();

    expect(p.template!.state, SectionState.partial);
    expect(p.template!.requiredLeft, 1);
    expect(p.canSubmit, isFalse);
    expect(
      p.template!.detailIn(englishLocalizations),
      'Client questions · 1 of 2 answered',
    );
  });

  test('every required question answered: done, counted, and submittable', () async {
    await pin();
    await finishFixedRequired();
    await saveAnswers({'note': 'first'});
    await saveAnswers({'facings': 4}); // the newest save wins
    final p = await progress();

    expect(p.template!.state, SectionState.done);
    expect(p.template!.answers, {'facings': 4});
    expect(p.canSubmit, isTrue);
    expect(p.doneCount, 5); // the 4 required fixed captures + the client's
  });

  test('optional client questions never block, even unanswered', () async {
    await pin(required: false);
    await finishFixedRequired();
    final p = await progress();

    expect(p.template!.isRequired, isFalse);
    expect(p.templateBlocking, isFalse);
    expect(p.canSubmit, isTrue);
    expect(p.template!.detailIn(englishLocalizations), 'Client questions · Optional');
  });

  test('another visit’s answers do not count', () async {
    await pin();
    await finishFixedRequired();
    await enqueue(templateResponseEntityType, {
      'visitDraftId': 'other',
      'templateId': 'tpl-1',
      'answers': {'facings': 4},
    });
    final p = await progress();

    expect(p.template!.state, SectionState.notStarted);
    expect(p.canSubmit, isFalse);
  });
}
