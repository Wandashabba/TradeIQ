import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/templates/domain/template_schema.dart';

// Required questions in a client's audit template (#122): which ones block a
// submit, and what counts as an answer.
final _schema = TemplateSchema.parse(const {
  'sections': [
    {
      'id': 'promo',
      'title': 'Promo',
      'fields': [
        {
          'id': 'standUp',
          'label': 'Stand up?',
          'type': 'boolean',
          'required': true,
        },
        {
          'id': 'facings',
          'label': 'Facings',
          'type': 'number',
          'required': true,
          'visibleIf': {'field': 'standUp', 'equals': true},
        },
        {'id': 'note', 'label': 'Note', 'type': 'text'},
        {'id': 'photo', 'label': 'Photo', 'type': 'photo', 'required': true},
        {'id': 'loose', 'label': 'Loose', 'type': 'text', 'required': 'yes'},
      ],
    },
    {
      'id': 'extras',
      'title': 'Extras',
      'fields': [
        {
          'id': 'zone',
          'label': 'Zone',
          'type': 'choice',
          'options': ['eye', 'floor'],
          'required': true,
        },
      ],
    },
  ],
});

TemplateField _field(String id) => _schema.fields.firstWhere((f) => f.id == id);

List<String> _missing(Map<String, Object?> answers) =>
    _schema.missingRequired(answers).map((f) => f.id).toList();

void main() {
  test('only a literal true makes a question required', () {
    expect(_field('standUp').required, isTrue);
    expect(_field('note').required, isFalse);
    // "yes" is not true: a sloppy schema must not start blocking submits.
    expect(_field('loose').required, isFalse);
  });

  test(
    'a hidden required question does not block; a required photo never does',
    () {
      // facings is hidden until standUp is true; photos cannot be captured yet.
      expect(_missing(const {}), ['standUp', 'zone']);
      expect(_field('photo').blocksSubmit, isFalse);
    },
  );

  test('revealing a required question makes it block until answered', () {
    expect(_missing(const {'standUp': true, 'zone': 'eye'}), ['facings']);
    expect(
      _missing(const {'standUp': true, 'zone': 'eye', 'facings': 3}),
      isEmpty,
    );
  });

  test(
    'a switch recorded off is an answer; blank text and bad types are not',
    () {
      expect(_missing(const {'standUp': false, 'zone': 'eye'}), isEmpty);
      expect(_field('note').isAnswered(const {'note': '   '}), isFalse);
      expect(_field('facings').isAnswered(const {'facings': '3'}), isFalse);
      expect(_field('zone').isAnswered(const {'zone': ''}), isFalse);
    },
  );

  test(
    'withSwitchDefaults records untouched visible switches as off, never overwriting',
    () {
      expect(_schema.withSwitchDefaults(const {}), {'standUp': false});
      expect(_schema.withSwitchDefaults(const {'standUp': true}), {
        'standUp': true,
      });
    },
  );

  test('withSwitchDefaults follows a switch revealed by another switch', () {
    final chained = TemplateSchema.parse(const {
      'sections': [
        {
          'id': 's',
          'fields': [
            {'id': 'a', 'label': 'A', 'type': 'boolean'},
            {
              'id': 'b',
              'label': 'B',
              'type': 'boolean',
              'visibleIf': {'field': 'a', 'equals': false},
            },
          ],
        },
      ],
    });
    expect(chained.withSwitchDefaults(const {}), {'a': false, 'b': false});
  });

  test('counts visible answerable questions and answers', () {
    const answers = {'standUp': true, 'facings': 2, 'note': 'ok'};
    // standUp, facings, note, loose, zone — the photo is not answerable.
    expect(_schema.questionCount(answers), 5);
    expect(_schema.answeredCount(answers), 3);
    expect(_schema.hasRequired, isTrue);
  });

  test(
    'a template of optional questions (and required photos) never blocks',
    () {
      final optional = TemplateSchema.parse(const {
        'sections': [
          {
            'id': 's',
            'fields': [
              {'id': 'n', 'label': 'N', 'type': 'text'},
              {'id': 'p', 'label': 'P', 'type': 'photo', 'required': true},
            ],
          },
        ],
      });
      expect(optional.hasRequired, isFalse);
      expect(optional.missingRequired(const {}), isEmpty);
    },
  );
}
