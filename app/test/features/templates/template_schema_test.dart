import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/templates/domain/template_schema.dart';

void main() {
  group('TemplateSchema.parse', () {
    test('parses sections, fields, options, weights, and visibleIf', () {
      final schema = TemplateSchema.parse(const {
        'sections': [
          {
            'id': 'availability',
            'title': 'Availability',
            'fields': [
              {'id': 'onShelf', 'label': 'On shelf?', 'type': 'boolean', 'weight': 10},
              {
                'id': 'facing',
                'label': 'Facing count',
                'type': 'number',
                'visibleIf': {'field': 'onShelf', 'equals': true},
              },
              {
                'id': 'shelfZone',
                'label': 'Shelf zone',
                'type': 'choice',
                'options': ['eye level', 'mid', 'floor'],
              },
            ],
          },
        ],
        'scoring': {'facing': 5},
      });

      expect(schema.sections, hasLength(1));
      final section = schema.sections.single;
      expect(section.id, 'availability');
      expect(section.title, 'Availability');
      expect(section.fields, hasLength(3));

      final onShelf = section.fields[0];
      expect(onShelf.type, TemplateFieldType.boolean);
      expect(onShelf.weight, 10);

      // Weight falls back to the top-level scoring map keyed by field id.
      final facing = section.fields[1];
      expect(facing.type, TemplateFieldType.number);
      expect(facing.weight, 5);
      expect(facing.visibleIf?.fieldId, 'onShelf');
      expect(facing.visibleIf?.equals, true);

      expect(section.fields[2].options, ['eye level', 'mid', 'floor']);
    });

    test('is tolerant: skips malformed sections/fields and unknown types', () {
      final schema = TemplateSchema.parse(const {
        'sections': [
          'not-a-map',
          {'fields': []}, // no id
          {
            'id': 'ok',
            'fields': [
              {'id': 'good', 'type': 'text'},
              {'id': 'mystery', 'type': 'hologram'}, // unknown type
              {'id': 'noOptions', 'type': 'choice'}, // choice needs options
              {'type': 'text'}, // no id
              'not-a-map',
            ],
          },
          {
            'id': 'emptied',
            'fields': [
              {'id': 'alien', 'type': 'hologram'},
            ],
          },
        ],
      });

      // Only the section that kept a renderable field survives.
      expect(schema.sections, hasLength(1));
      expect(schema.sections.single.fields.single.id, 'good');
    });

    test('returns no sections for an empty or shapeless schema', () {
      expect(TemplateSchema.parse(const {}).sections, isEmpty);
      expect(
        TemplateSchema.parse(const {'sections': 'nope'}).sections,
        isEmpty,
      );
    });

    test('falls back to ids when title/label are missing', () {
      final schema = TemplateSchema.parse(const {
        'sections': [
          {
            'id': 's1',
            'fields': [
              {'id': 'f1', 'type': 'text'},
            ],
          },
        ],
      });
      expect(schema.sections.single.title, 's1');
      expect(schema.sections.single.fields.single.label, 'f1');
    });
  });

  group('visibility and scoring', () {
    final schema = TemplateSchema.parse(const {
      'sections': [
        {
          'id': 's1',
          'fields': [
            {'id': 'onShelf', 'type': 'boolean', 'weight': 10},
            {
              'id': 'facing',
              'type': 'number',
              'weight': 5,
              'visibleIf': {'field': 'onShelf', 'equals': true},
            },
            {'id': 'note', 'type': 'text', 'weight': 2},
          ],
        },
      ],
    });

    test('maxScore sums every weighted field', () {
      expect(schema.maxScore, 17);
    });

    // THE FAILURE, WRITTEN OUT: a manager previews a template that scores a
    // photo question, answers every question the preview can accept, reaches
    // "Finish preview" — and the meter still sits short of the stated
    // maximum. They raise a ticket against a template that is correct.
    //
    // `scoring` is parsed as a flat id→weight map with no type filter, so a
    // weighted photo field is legal JSON; `scoreFor` hard-codes photo to earn
    // nothing until capture lands. The maximum has to be the REACHABLE one.
    test('maxScore claims only what the preview can reach', () {
      final withPhoto = TemplateSchema.parse(const {
        'sections': [
          {
            'id': 's1',
            'fields': [
              {'id': 'onShelf', 'type': 'boolean'},
              {'id': 'shot', 'type': 'photo'},
            ],
          },
        ],
        'scoring': {'onShelf': 10, 'shot': 6},
      });

      // The photo's weight is parsed — it is a legal template — and simply
      // cannot be earned.
      expect(withPhoto.sections.single.fields[1].weight, 6);
      expect(withPhoto.scoreFor(const {'onShelf': true, 'shot': 'p-1'}), 10);

      expect(
        withPhoto.maxScore,
        10,
        reason:
            'Every answerable question answered must be able to reach the '
            'maximum the tile states.',
      );
      expect(
        withPhoto.scoreFor(const {'onShelf': true, 'shot': 'p-1'}),
        withPhoto.maxScore,
      );
    });

    test('a conditional field is hidden until its trigger answer matches', () {
      final facing = schema.sections.single.fields[1];
      expect(facing.isVisible(const {}), isFalse);
      expect(facing.isVisible(const {'onShelf': false}), isFalse);
      expect(facing.isVisible(const {'onShelf': true}), isTrue);
    });

    test('scoreFor earns weights for answered visible fields only', () {
      expect(schema.scoreFor(const {}), 0);
      // A false boolean earns nothing; the hidden number never scores.
      expect(schema.scoreFor(const {'onShelf': false, 'facing': 4}), 0);
      expect(schema.scoreFor(const {'onShelf': true}), 10);
      expect(schema.scoreFor(const {'onShelf': true, 'facing': 4}), 15);
      expect(
        schema.scoreFor(const {'onShelf': true, 'facing': 4, 'note': 'ok'}),
        17,
      );
      // An empty text answer earns nothing.
      expect(schema.scoreFor(const {'onShelf': true, 'note': ''}), 10);
    });
  });
}
