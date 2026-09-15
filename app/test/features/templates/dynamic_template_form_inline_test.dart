import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/features/templates/domain/template_schema.dart';
import 'package:tradeiq_app/features/templates/presentation/dynamic_template_form.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

// The inline layout the audit hub's client-questions section uses (#122).
final _schema = TemplateSchema.parse(const {
  'sections': [
    {
      'id': 'promo',
      'title': 'Promo stand',
      'fields': [
        {'id': 'standUp', 'label': 'Is the stand up?', 'type': 'boolean', 'required': true},
        {'id': 'facings', 'label': 'Promo facings', 'type': 'number', 'required': true},
      ],
    },
    {
      'id': 'extras',
      'title': 'Extras',
      'fields': [
        {'id': 'note', 'label': 'Anything else?', 'type': 'text'},
        {'id': 'shelfPhoto', 'label': 'Shelf photo', 'type': 'photo'},
      ],
    },
  ],
});

Widget _app({
  Map<String, Object?> initial = const {},
  ValueChanged<Map<String, Object?>>? onChanged,
  bool showErrors = false,
  ThemeData? theme,
  Locale? locale,
}) => MaterialApp(
  theme: theme,
  locale: locale,
  supportedLocales: appSupportedLocales,
  localizationsDelegates: appLocalizationsDelegates,
  localeListResolutionCallback: resolveAppLocale,
  home: Scaffold(
    body: SingleChildScrollView(
      child: DynamicTemplateForm.inline(
        schema: _schema,
        initialAnswers: initial,
        onChanged: onChanged ?? (_) {},
        showRequiredErrors: showErrors,
      ),
    ),
  ),
);

void main() {
  testWidgets('stacks every section in one column, with no Next/Back', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    expect(find.byKey(const ValueKey('template-section-promo')), findsOneWidget);
    expect(find.byKey(const ValueKey('template-section-extras')), findsOneWidget);
    expect(find.text('Is the stand up?'), findsOneWidget);
    expect(find.text('Anything else?'), findsOneWidget);
    expect(find.byKey(const ValueKey('form-next')), findsNothing);
    // Required questions say so, in words.
    expect(find.text('Required'), findsNWidgets(2));
    expect(
      find.text('Photo questions can’t be answered in the app yet'),
      findsOneWidget,
    );
  });

  testWidgets('starts from saved answers and reports every change', (
    tester,
  ) async {
    Map<String, Object?>? last;
    await tester.pumpWidget(
      _app(initial: const {'facings': 7}, onChanged: (a) => last = a),
    );

    expect(find.text('7'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('field-standUp')));
    await tester.pump();
    expect(last, {'facings': 7, 'standUp': true});

    await tester.enterText(find.byKey(const ValueKey('field-note')), 'Stand bent');
    await tester.pump();
    expect(last, {'facings': 7, 'standUp': true, 'note': 'Stand bent'});

    await tester.enterText(find.byKey(const ValueKey('field-facings')), '');
    await tester.pump();
    expect(last!.containsKey('facings'), isFalse);
  });

  testWidgets('after a save attempt, an unanswered required question says so', (
    tester,
  ) async {
    await tester.pumpWidget(_app(showErrors: true));

    // The number is unanswered; the switch always shows a value, so it never
    // carries the error.
    expect(find.text('Answer this before you submit'), findsOneWidget);
  });

  for (final (name, theme) in [('light', AppTheme.light), ('night', AppTheme.dark)]) {
    testWidgets('$name: each question sits on a no-blur glass tile', (
      tester,
    ) async {
      await tester.pumpWidget(_app(theme: theme()));

      // Glass section titles are kickers.
      expect(find.text('PROMO STAND'), findsOneWidget);
      for (final id in ['standUp', 'facings', 'note', 'shelfPhoto']) {
        final tile = tester.widget<GlassPane>(
          find
              .ancestor(
                of: find.byKey(ValueKey('field-$id')),
                matching: find.byType(GlassPane),
              )
              .first,
        );
        expect(tile.kind, GlassKind.tile, reason: '$name $id');
        expect(tile.blur, isFalse, reason: '$name $id');
      }
    });
  }

  testWidgets('Afrikaans: the form’s own words translate, the questions do not', (
    tester,
  ) async {
    await tester.pumpWidget(_app(locale: const Locale('af'), showErrors: true));
    await tester.pumpAndSettle();

    expect(find.text('Verpligtend'), findsOneWidget); // the switch's marker
    expect(find.text('Beantwoord dit voor jy indien'), findsOneWidget);
    expect(
      find.text('Fotovrae kan nog nie in die app beantwoord word nie'),
      findsOneWidget,
    );
    // Client-authored content is shown as written.
    expect(find.text('Is the stand up?'), findsOneWidget);
    expect(find.text('Required'), findsNothing);
  });
}
