import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state/toast.dart';
import 'package:tradeiq_app/features/assistant/answer/web_sources.dart';
import 'package:tradeiq_app/features/assistant/data/assistant_events.dart';

import 'ask_harness.dart' show askBlock, askSkins, screenText;

WebSource source(
  String title,
  String url, {
  String domain = 'iol.co.za',
  String? snippet,
  String? pageAge,
}) => WebSource(
  title: title,
  url: Uri.parse(url),
  domain: domain,
  pageAge: pageAge,
  retrievedAt: DateTime.utc(2026, 9, 17, 10, 12),
  snippet: snippet,
);

final List<WebSource> sources = <WebSource>[
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

Future<void> pumpSources(
  WidgetTester tester,
  Widget child, {
  TiqSkin? skin,
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    askBlock(child, skin: skin, locale: locale, textScale: textScale),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final skin in askSkins) {
    final name = skin.mode.name;

    testWidgets('$name: the rule, the index, each domain and title', (
      tester,
    ) async {
      await pumpSources(tester, WebSources(sources: sources), skin: skin);

      expect(tester.takeException(), isNull);
      final text = screenText(tester);
      // Sentence case on a knocked-out rule — the same grammar as the
      // callout, and never the uppercase eyebrow the old build used.
      expect(text, contains('Sources'));
      expect(text, isNot(contains('SOURCES')));
      expect(text, contains('iol.co.za'));
      expect(text, contains('Shoprite launches new stores in Gauteng'));
      expect(text, contains('news24.com'));
      expect(text, contains('Retail sales slow in August'));
      expect(text, contains('3 days ago'));
      expect(text, contains('opens in browser'));
      // The index is a figure, not a light: it goes through FigureSlot and
      // reads 1, 2 in the reader's own digits.
      expect(text, contains('1'));
      expect(text, contains('2'));
    });
  }

  testWidgets('the title wraps rather than truncating to one line', (
    tester,
  ) async {
    // A one-line row is where long titles and Afrikaans both die. The domain
    // middle-truncates first: the host is the half you cannot guess.
    await pumpSources(
      tester,
      WebSources(
        sources: <WebSource>[
          source(
            'A very long headline ' * 20,
            'https://e.com/a',
            domain: 'e.com',
          ),
        ],
      ),
    );

    final title = tester.widget<Text>(find.textContaining('A very long'));
    expect(title.maxLines, greaterThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a turn that searched and found nothing says so', (tester) async {
    // A fact about the search, not an empty state — and never an empty
    // "Sources" heading with nothing under it.
    await pumpSources(tester, const WebSources(sources: [], searched: true));
    expect(
      screenText(tester),
      contains('The web search returned nothing usable.'),
    );

    await pumpSources(tester, const WebSources(sources: []));
    expect(find.byKey(const ValueKey<String>('web-sources')), findsNothing);
  });

  testWidgets('more than four rows: four, and a row that shows the rest', (
    tester,
  ) async {
    await pumpSources(
      tester,
      WebSources(
        sources: <WebSource>[
          for (var i = 0; i < 6; i++)
            source('Headline $i', 'https://e$i.com/a', domain: 'e$i.com'),
        ],
      ),
    );

    expect(screenText(tester), isNot(contains('Headline 5')));
    final showAll = find.byKey(const ValueKey<String>('web-sources-show-all'));
    expect(screenText(tester), contains('Show all 6 sources'));
    await tester.tap(showAll);
    await tester.pumpAndSettle();
    expect(screenText(tester), contains('Headline 5'));
  });

  testWidgets('tapping a source opens its exact https url', (tester) async {
    final opened = <Uri>[];
    await pumpSources(
      tester,
      WebSources(
        sources: sources,
        launcher: (url) async {
          opened.add(url);
          return true;
        },
      ),
    );

    await tester.tap(find.text('Retail sales slow in August'));
    await tester.pump();
    expect(opened, <Uri>[Uri.parse('https://www.news24.com/fin24/retail')]);

    await tester.tap(find.text('iol.co.za'));
    await tester.pump();
    expect(
      opened.last,
      Uri.parse('https://www.iol.co.za/business/shoprite?x=1'),
    );
  });

  testWidgets('a platform that refuses keeps the row and says what to do', (
    tester,
  ) async {
    // The row is still provenance. It never disappears because a browser
    // could not be reached.
    await pumpSources(
      tester,
      WebSources(sources: sources, launcher: (url) async => false),
    );

    await tester.tap(find.text('iol.co.za'));
    await tester.pumpAndSettle();
    expect(screenText(tester), contains('Could not open a browser'));
    expect(screenText(tester), contains('iol.co.za'));
  });

  testWidgets('refuses to launch a non-web url even if one got through', (
    tester,
  ) async {
    final opened = <Uri>[];
    await pumpSources(
      tester,
      WebSources(
        sources: <WebSource>[
          source('Sneaky', 'javascript:alert(1)', domain: 'x'),
        ],
        launcher: (url) async {
          opened.add(url);
          return true;
        },
      ),
    );
    await tester.tap(find.text('Sneaky'));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    expect(await openWebSource(Uri.parse('javascript:alert(1)')), isFalse);
    expect(await openWebSource(Uri.parse('data:text/html,hi')), isFalse);
  });

  testWidgets('long-press copies the address and previews it as plain text', (
    tester,
  ) async {
    // The preview costs the transcript no height, and a snippet off the open
    // web is never parsed as markdown.
    await pumpSources(
      tester,
      WebSources(
        sources: <WebSource>[
          source(
            'Shoprite **launches**',
            'https://e.com/a',
            domain: 'e.com',
            snippet:
                'Shoprite said **bold** and [a link](https://evil.example)',
          ),
        ],
      ),
    );

    // The title shows its asterisks literally.
    expect(screenText(tester), contains('Shoprite **launches**'));

    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add(
            (call.arguments as Map<Object?, Object?>)['text']! as String,
          );
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.longPress(find.text('e.com'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // The address is on the clipboard and the preview is in the toast, in
    // the page's own words — asterisks and all, never rendered as markdown.
    final toast = tester.widget<TorchToast>(find.byType(TorchToast));
    expect(toast.message, startsWith('Address copied'));
    expect(
      toast.message,
      contains('Shoprite said **bold** and [a link](https://evil.example)'),
    );
    expect(copied, <String>['https://e.com/a']);
    // Let the toast's dwell timer run out inside the test body.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('each source is one accessible link', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpSources(tester, WebSources(sources: sources));

    final node = tester.getSemantics(
      find.byKey(const ValueKey<String>('web-source-0')),
    );
    expect(
      node.label,
      'Web source 1, iol.co.za, Shoprite launches new stores in Gauteng, '
      'opens in browser',
    );
    final data = node.getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    // Announced AND reachable: the row declares the action itself, so a
    // screen-reader double-tap opens the page.
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.hasAction(SemanticsAction.longPress), isTrue);
    handle.dispose();
  });

  testWidgets('at 2.0x in Afrikaans the rows grow rather than clipping', (
    tester,
  ) async {
    for (final skin in askSkins) {
      await pumpSources(
        tester,
        WebSources(sources: sources),
        skin: skin,
        locale: const Locale('af'),
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull, reason: skin.mode.name);
    }
  });
}
