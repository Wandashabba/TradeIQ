import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/core/widgets/lumen_kit.dart';
import 'package:tradeiq_app/features/templates/domain/template_schema.dart';
import 'package:tradeiq_app/features/templates/presentation/dynamic_template_form.dart';

final _schema = TemplateSchema.parse(const {
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
      ],
    },
    {
      'id': 'extras',
      'title': 'Extras',
      'fields': [
        {
          'id': 'zone',
          'label': 'Shelf zone',
          'type': 'choice',
          'options': ['eye level', 'floor'],
        },
        {'id': 'note', 'label': 'Notes', 'type': 'text'},
        {'id': 'shelfPhoto', 'label': 'Shelf photo', 'type': 'photo'},
      ],
    },
  ],
});

Widget _app({
  TemplateSchema? schema,
  ValueChanged<Map<String, Object?>>? onSubmit,
  ThemeData? theme,
}) =>
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: DynamicTemplateForm(
          schema: schema ?? _schema,
          onSubmit: onSubmit ?? (_) {},
        ),
      ),
    );

void main() {
  testWidgets('renders one section at a time and steps with Next/Back', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    expect(find.textContaining('Section 1 of 2'), findsOneWidget);
    expect(find.text('On shelf?'), findsOneWidget);
    expect(find.text('Shelf zone'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('form-next')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Section 2 of 2'), findsOneWidget);
    expect(find.text('Shelf zone'), findsOneWidget);
    expect(find.text('On shelf?'), findsNothing);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Section 1 of 2'), findsOneWidget);
  });

  testWidgets('a conditional field appears once its trigger is answered', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    expect(find.text('Facing count'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('field-onShelf')));
    await tester.pumpAndSettle();

    expect(find.text('Facing count'), findsOneWidget);
  });

  testWidgets('shows a live score preview for weighted fields', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    expect(find.text('Score preview: 0 / 10'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('field-onShelf')));
    await tester.pumpAndSettle();

    expect(find.text('Score preview: 10 / 10'), findsOneWidget);
  });

  testWidgets('collects typed answers across sections into onSubmit', (
    tester,
  ) async {
    Map<String, Object?>? submitted;
    await tester.pumpWidget(_app(onSubmit: (answers) => submitted = answers));

    await tester.tap(find.byKey(const ValueKey('field-onShelf')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('field-facing')), '4');
    await tester.tap(find.byKey(const ValueKey('form-next')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('field-zone')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('eye level').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('field-note')),
      'Clean shelf',
    );

    await tester.tap(find.byKey(const ValueKey('form-next')));
    await tester.pumpAndSettle();

    expect(submitted, {
      'onShelf': true,
      'facing': 4,
      'zone': 'eye level',
      'note': 'Clean shelf',
    });
  });

  testWidgets('photo fields render as a disabled placeholder', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.byKey(const ValueKey('form-next')));
    await tester.pumpAndSettle();

    expect(find.text('Shelf photo'), findsOneWidget);
    expect(
      find.text('Photo capture coming with audit integration'),
      findsOneWidget,
    );
  });

  testWidgets('an empty schema shows a friendly message', (tester) async {
    await tester.pumpWidget(
      _app(schema: TemplateSchema.parse(const {})),
    );
    expect(
      find.text('This template has no form sections yet.'),
      findsOneWidget,
    );
  });

  testWidgets('light: kicker and title, fields on glass, Next is the glass action',
      (tester) async {
    Map<String, Object?>? submitted;
    await tester.pumpWidget(
      _app(theme: AppTheme.light(), onSubmit: (a) => submitted = a),
    );
    await tester.pumpAndSettle();

    expect(find.text('SECTION 1 OF 2'), findsOneWidget);
    expect(find.text('Availability'), findsOneWidget);
    // The running score is its own mono figure.
    final score = tester.widget<Text>(find.text('0 / 10'));
    expect(score.style?.fontFamily, 'JetBrains Mono');

    final toggle = find.byKey(const ValueKey('field-onShelf'));
    expect(
      tester
          .widget<GlassPane>(
            find.ancestor(of: toggle, matching: find.byType(GlassPane)).first,
          )
          .kind,
      GlassKind.tile,
    );
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('10 / 10'), findsOneWidget);

    final next = find.byKey(const ValueKey('form-next'));
    expect(tester.widget(next), isA<GlassPrimaryButton>());
    expect(find.byType(ElevatedButton), findsNothing);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('SECTION 2 OF 2'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('SECTION 1 OF 2'), findsOneWidget);

    await tester.tap(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(submitted, {'onShelf': true});
  });
}
