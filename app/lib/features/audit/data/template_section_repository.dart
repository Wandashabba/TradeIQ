import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/local_db.dart';
import '../../../core/sync/sync_service.dart';
import '../../templates/data/templates_repository.dart';
import '../../templates/domain/template_schema.dart';

/// The outbox entity the client-questions section writes. Flushed to
/// `POST /template-responses` by [HttpQueueFlusher].
const templateResponseEntityType = 'template_response';

/// The client's audit template, as pinned to one visit (#122).
///
/// Its questions are an extra section after S1–S10: they supplement the fixed
/// audit and never feed the perfect-store score. [name] and the questions are
/// the client's own words and are shown untranslated.
class ClientTemplate {
  ClientTemplate({
    required this.templateId,
    required this.name,
    required this.version,
    required this.schemaJson,
  }) : schema = TemplateSchema.parse(schemaJson);

  final String templateId;
  final String name;

  /// The version this visit answers against.
  final int version;
  final Map<String, dynamic> schemaJson;
  final TemplateSchema schema;
}

ClientTemplate? clientTemplateFrom(PinnedVisitTemplate? row) {
  final id = row?.templateId;
  final json = row?.schemaJson;
  if (row == null || id == null || json == null) return null;
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) return null;
    return ClientTemplate(
      templateId: id,
      name: row.templateName ?? '',
      version: row.templateVersion ?? 1,
      schemaJson: decoded,
    );
  } catch (_) {
    return null;
  }
}

/// The newest saved answers for [templateId] on [visitDraftId] among [rows],
/// or null when the section was never saved. The outbox IS the local store of
/// a section's captures — the same rule every other section follows — so this
/// survives the app being killed mid-visit.
Map<String, Object?>? latestTemplateAnswers(
  Iterable<SyncQueueItem> rows, {
  required String visitDraftId,
  required String templateId,
}) {
  SyncQueueItem? latest;
  Map<String, dynamic>? latestPayload;
  for (final row in rows) {
    if (row.entityType != templateResponseEntityType) continue;
    if (latest != null && row.id < latest.id) continue;
    final Object? payload;
    try {
      payload = jsonDecode(row.payloadJson);
    } catch (_) {
      continue;
    }
    if (payload is! Map<String, dynamic> ||
        payload['visitDraftId'] != visitDraftId ||
        payload['templateId'] != templateId ||
        payload['answers'] is! Map) {
      continue;
    }
    latest = row;
    latestPayload = payload;
  }
  final answers = latestPayload?['answers'];
  return answers is Map ? Map<String, Object?>.from(answers) : null;
}

abstract class TemplateSectionRepository {
  /// Pins the client's audit template to a visit, once. Best-effort: offline
  /// it falls back to the last template this agent was given, and with
  /// nothing known it pins nothing, so the hub looks exactly as it does for a
  /// client without a template.
  Future<void> pinForVisit(String visitDraftId);

  /// The answers last saved for this visit, or empty.
  Future<Map<String, Object?>> savedAnswers({
    required String visitDraftId,
    required String templateId,
  });

  /// Saves the answers locally and queues them for `POST /template-responses`.
  Future<void> saveAnswers({
    required String visitDraftId,
    required ClientTemplate template,
    required Map<String, Object?> answers,
  });
}

class DriftTemplateSectionRepository implements TemplateSectionRepository {
  DriftTemplateSectionRepository({
    required this.db,
    required this.syncService,
    required this.templates,
  });

  final LocalDb db;
  final SyncService syncService;
  final TemplatesRepository templates;
  static const _uuid = Uuid();

  @override
  Future<void> pinForVisit(String visitDraftId) async {
    final existing = await (db.select(
      db.pinnedVisitTemplates,
    )..where((t) => t.visitDraftId.equals(visitDraftId))).getSingleOrNull();
    if (existing != null) return;

    final owner = currentLocalUserId;
    AuditTemplateDetail? selected;
    try {
      selected = await templates.fetchSelected();
    } catch (_) {
      // No signal (or no server). An audit started in a dead zone should still
      // ask the client's questions, so fall back to what this agent was last
      // given — which may itself be "no template".
      if (owner == null) return;
      final last =
          await (db.select(db.pinnedVisitTemplates)
                ..where((t) => t.userId.equals(owner))
                ..orderBy([(t) => OrderingTerm.desc(t.pinnedAt)])
                ..limit(1))
              .getSingleOrNull();
      if (last == null) return;
      await _pin(
        visitDraftId,
        templateId: last.templateId,
        name: last.templateName,
        version: last.templateVersion,
        schemaJson: last.schemaJson,
        owner: owner,
      );
      return;
    }

    await _pin(
      visitDraftId,
      templateId: selected?.template.id,
      name: selected?.template.name,
      version: selected?.template.version,
      schemaJson: selected == null ? null : jsonEncode(selected.schema),
      owner: owner,
    );
  }

  Future<void> _pin(
    String visitDraftId, {
    required String? templateId,
    required String? name,
    required int? version,
    required String? schemaJson,
    required String? owner,
  }) {
    return db
        .into(db.pinnedVisitTemplates)
        .insert(
          PinnedVisitTemplatesCompanion.insert(
            visitDraftId: visitDraftId,
            templateId: Value(templateId),
            templateName: Value(name),
            templateVersion: Value(version),
            schemaJson: Value(schemaJson),
            userId: Value(owner),
            pinnedAt: Value(DateTime.now()),
          ),
          // First pin wins: the questions never change under a visit.
          mode: InsertMode.insertOrIgnore,
        );
  }

  @override
  Future<Map<String, Object?>> savedAnswers({
    required String visitDraftId,
    required String templateId,
  }) async {
    final rows = await (db.select(
      db.syncQueueItems,
    )..where((t) => t.entityType.equals(templateResponseEntityType))).get();
    return latestTemplateAnswers(
          rows,
          visitDraftId: visitDraftId,
          templateId: templateId,
        ) ??
        const {};
  }

  @override
  Future<void> saveAnswers({
    required String visitDraftId,
    required ClientTemplate template,
    required Map<String, Object?> answers,
  }) async {
    final recorded = template.schema.withSwitchDefaults(answers);
    await db.transaction(() async {
      // The server upserts per (visit, template), so an earlier save that has
      // not been sent yet is superseded by this one. Dropping it keeps the
      // outbox to one row per section rather than one per tap of Save.
      final unsent =
          await (db.select(db.syncQueueItems)..where(
                (t) =>
                    t.entityType.equals(templateResponseEntityType) &
                    t.synced.equals(false),
              ))
              .get();
      for (final row in unsent) {
        final Object? payload;
        try {
          payload = jsonDecode(row.payloadJson);
        } catch (_) {
          continue;
        }
        if (payload is Map &&
            payload['visitDraftId'] == visitDraftId &&
            payload['templateId'] == template.templateId) {
          await (db.delete(
            db.syncQueueItems,
          )..where((t) => t.id.equals(row.id))).go();
        }
      }
      await db.enqueue(
        entityType: templateResponseEntityType,
        entityId: _uuid.v4(),
        payloadJson: jsonEncode({
          'visitDraftId': visitDraftId,
          'templateId': template.templateId,
          'templateVersion': template.version,
          'answers': recorded,
        }),
      );
    });

    try {
      await syncService.flushPending();
    } catch (_) {
      // Best-effort: the answers are queued and retried on the next flush.
    }
  }
}

final templateSectionRepositoryProvider = Provider<TemplateSectionRepository>(
  (ref) => DriftTemplateSectionRepository(
    db: ref.read(localDbProvider),
    syncService: ref.read(syncServiceProvider),
    templates: ref.read(templatesRepositoryProvider),
  ),
);

/// The client template pinned to a visit, or null when the visit has none.
/// Read from the local database only — never the network — so the hub and the
/// submit gate work the same with and without signal.
final visitTemplateProvider =
    StreamProvider.family<ClientTemplate?, String>((ref, visitDraftId) {
      final db = ref.read(localDbProvider);
      return (db.select(db.pinnedVisitTemplates)
            ..where((t) => t.visitDraftId.equals(visitDraftId)))
          .watchSingleOrNull()
          .map(clientTemplateFrom);
    });
