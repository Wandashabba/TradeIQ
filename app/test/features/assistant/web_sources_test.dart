import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/features/assistant/answer/web_sources.dart';
import 'package:tradeiq_app/features/assistant/data/assistant_events.dart';

Widget wrap(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? AppTheme.dark(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: 600, child: child),
        ),
      ),
    );

WebSource source(
  String title,
  String url, {
  String domain = 'iol.co.za',
  String? snippet,
  String? pageAge,
}) =>
    WebSource(
      title: title,
      url: Uri.parse(url),
      domain: domain,
      pageAge: pageAge,
      retrievedAt: DateTime.utc(2026, 9, 17, 10, 12),
      snippet: snippet,
    );

void main() {
  final sources = [
    source(
      'Shoprite launches new stores in Gauteng',
      'https://www.iol.co.za/business/shoprite?x=1',
      pageAge: '3 days ago',
    ),
    source(
      'Retail sales slow in August',
      'https://www.news24.com/fin24/retail',
      domain: 'news24.com',
    ),
  ];

  for (final (name, theme) in [
    ('glass dark', AppTheme.dark()),
    ('glass light', AppTheme.light()),
  ]) {
    testWidgets('renders the label and each domain and title ($name)',
        (tester) async {
      await tester.pumpWidget(wrap(WebSources(sources: sources), theme: theme));

      expect(find.text('Web sources'), findsOneWidget);
      expect(find.text('iol.co.za'), findsOneWidget);
      expect(find.text('Shoprite launches new stores in Gauteng'), findsOneWidget);
      expect(find.text('news24.com'), findsOneWidget);
      expect(find.text('Retail sales slow in August'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3 days ago'), findsOneWidget);
    });
  }

  testWidgets('renders on a bare theme with no Lumen extension', (tester) async {
    await tester.pumpWidget(wrap(WebSources(sources: sources), theme: ThemeData()));
    expect(find.text('Web sources'), findsOneWidget);
  });

  testWidgets('titles are ellipsised to one line', (tester) async {
    await tester.pumpWidget(wrap(WebSources(sources: [
      source('A very long headline ' * 20, 'https://e.com/a', domain: 'e.com'),
    ])));
    final title = tester.widget<Text>(find.textContaining('A very long'));
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a source opens its exact https url', (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(wrap(WebSources(
      sources: sources,
      launcher: (url) async {
        opened.add(url);
        return true;
      },
    )));

    await tester.tap(find.text('Retail sales slow in August'));
    await tester.pump();
    expect(opened, [Uri.parse('https://www.news24.com/fin24/retail')]);

    await tester.tap(find.text('iol.co.za'));
    await tester.pump();
    expect(opened.last, Uri.parse('https://www.iol.co.za/business/shoprite?x=1'));
  });

  testWidgets('refuses to launch a non-web url even if one got through',
      (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(wrap(WebSources(
      sources: [source('Sneaky', 'javascript:alert(1)', domain: 'x')],
      launcher: (url) async {
        opened.add(url);
        return true;
      },
    )));
    await tester.tap(find.text('Sneaky'));
    await tester.pump();
    expect(opened, isEmpty);
    expect(await openWebSource(Uri.parse('javascript:alert(1)')), isFalse);
    expect(await openWebSource(Uri.parse('data:text/html,hi')), isFalse);
  });

  testWidgets('renders nothing for an empty list', (tester) async {
    await tester.pumpWidget(wrap(const WebSources(sources: [])));
    expect(find.text('Web sources'), findsNothing);
    expect(find.byKey(const ValueKey('web-sources')), findsNothing);
  });

  testWidgets('the snippet is plain text, never markdown', (tester) async {
    await tester.pumpWidget(wrap(WebSources(sources: [
      source(
        'Shoprite **launches**',
        'https://e.com/a',
        domain: 'e.com',
        snippet: 'Shoprite said **bold** and [a link](https://evil.example)',
      ),
    ])));

    // The title shows its asterisks literally.
    expect(find.text('Shoprite **launches**'), findsOneWidget);

    await tester.longPress(find.text('e.com'));
    await tester.pumpAndSettle();
    expect(
      find.text('Shoprite said **bold** and [a link](https://evil.example)'),
      findsOneWidget,
    );
  });

  testWidgets('each source is one accessible link', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(wrap(WebSources(sources: sources)));

    final node = tester.getSemantics(find.byKey(const ValueKey('web-source-0')));
    expect(
      node.label,
      'Web source: Shoprite launches new stores in Gauteng, iol.co.za, '
      'opens in browser',
    );
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isLink, isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });
}
