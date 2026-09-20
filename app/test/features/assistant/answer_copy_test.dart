import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/tiq_number.dart';
import 'package:tradeiq_app/features/assistant/answer/answer_copy.dart';
import 'package:tradeiq_app/features/assistant/answer/ask_turn.dart';
import 'package:tradeiq_app/features/assistant/data/assistant_events.dart';
import 'package:tradeiq_app/features/assistant/data/chat_controller.dart';

import 'ask_harness.dart' show askBlock;

/// A turn with prose, internal figures, an outside figure and a cited source.
ChatMessage answer() => ChatMessage(
  role: ChatRole.assistant,
  text:
      'Sell-in held steady.\n\n'
      '- __Soweto__ fell *hardest*\n'
      '- Sandton rose\n',
  artifacts: const <ChatArtifact>[
    ChatArtifact(
      id: 'getSales-stat_tiles-1',
      type: 'stat_tiles',
      params: <String, dynamic>{},
      data: <String, dynamic>{
        'origin': 'internal',
        'tiles': <Map<String, dynamic>>[
          <String, dynamic>{
            'label': 'Sell-in, units',
            'value': 1284990.5,
            'unit': 'units',
            'delta': <String, dynamic>{
              'value': 12.4,
              'unit': 'pct',
              'direction': 'down',
              'sentiment': 'bad',
            },
            'comparedTo': "vs Aug '25",
          },
          <String, dynamic>{
            'label': 'Shelf share',
            'value': null,
            'unit': 'pct',
          },
        ],
      },
    ),
    ChatArtifact(
      id: 'getCompetitorShelfPrices-stat_tiles-1',
      type: 'stat_tiles',
      params: <String, dynamic>{},
      data: <String, dynamic>{
        'origin': 'competitor_prices',
        'publisher': 'news24.com',
        'outsideData': true,
        'tiles': <Map<String, dynamic>>[
          <String, dynamic>{
            'label': 'Competitor shelf price',
            'value': 34.99,
            'unit': 'currency',
            'decimals': 2,
          },
        ],
      },
    ),
  ],
  tools: const <ToolActivity>[
    ToolActivity(name: 'getSalesPerformance', pillar: 'sales', ok: true),
    ToolActivity(name: 'webSearch', pillar: 'sales', ok: true),
  ],
  sources: <WebSource>[
    WebSource(
      title: 'Retail sales slow in August',
      url: Uri.parse('https://www.news24.com/fin24/retail'),
      domain: 'news24.com',
      retrievedAt: DateTime.utc(2026, 9, 17),
    ),
  ],
);

Future<String> copied(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  late String text;
  await tester.pumpWidget(
    askBlock(
      Builder(
        builder: (context) {
          text = answerPlainText(
            context,
            message: answer(),
            question: 'How did sell-in do?',
          );
          return const SizedBox.shrink();
        },
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
  return text;
}

void main() {
  testWidgets('the copy carries the prose, the figures and the sources', (
    tester,
  ) async {
    final text = await copied(tester);

    expect(text, contains('Your question: How did sell-in do?'));
    expect(text, contains('Sell-in held steady.'));
    // The markers are the app's internals, not the words.
    expect(text, contains('- Soweto fell hardest'));
    expect(text, isNot(contains('*')));
    expect(text, isNot(contains('_')));
    expect(text, contains('Sell-in, units: 1,284,990.5'));
    expect(text, contains("vs Aug '25"));
    expect(text, contains('${minusSign}12.4%'));
    expect(text, contains('news24.com'));
    expect(text, contains('https://www.news24.com/fin24/retail'));
  });

  testWidgets('a chart pastes as where it started and where it ended', (
    tester,
  ) async {
    late String text;
    await tester.pumpWidget(
      askBlock(
        Builder(
          builder: (context) {
            text = answerPlainText(
              context,
              message: const ChatMessage(
                role: ChatRole.assistant,
                text: 'Availability recovered.',
                artifacts: <ChatArtifact>[
                  ChatArtifact(
                    id: 'getMetricTrend-0',
                    type: 'trend_chart',
                    params: <String, dynamic>{},
                    data: <String, dynamic>{
                      'metric': 'availability',
                      'points': <Map<String, dynamic>>[
                        <String, dynamic>{'period': '2026-06', 'value': 58},
                        <String, dynamic>{'period': '2026-08', 'value': 66.4},
                      ],
                    },
                  ),
                ],
              ),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // A picture cannot be pasted; what the plot said can.
    expect(text, contains('On-shelf availability'));
    expect(text, contains('58.0%'));
    expect(text, contains('66.4%'));
  });

  testWidgets('an unknown figure pastes as an unknown, never as a zero', (
    tester,
  ) async {
    final text = await copied(tester);

    expect(text, contains('Shelf share: $emDash'));
    expect(text, contains('Nothing measured in this window'));
    expect(text, isNot(contains('Shelf share: 0')));
  });

  testWidgets('outside data stays outside, with the source it came from', (
    tester,
  ) async {
    final text = await copied(tester);

    final figures = text.indexOf('Figures for this answer:');
    final outside = text.indexOf('Outside data:');
    expect(figures, greaterThan(-1));
    expect(outside, greaterThan(figures));
    // Bracketed with the index of the source it came from, so a figure that
    // was never ours cannot be pasted into a column of ours.
    expect(text, contains('Competitor shelf price: 34.99 [1]'));
    expect(
      text.substring(figures, outside),
      isNot(contains('Competitor shelf price')),
    );
  });

  testWidgets('in Afrikaans it pastes the reader\'s own separators', (
    tester,
  ) async {
    final text = await copied(tester, locale: const Locale('af'));

    expect(text, contains('1 284 990,5'));
    expect(text, isNot(contains('1,284,990.5')));
    expect(text, contains('Data van buite:'));
  });

  testWidgets('Copy puts it on the clipboard and says so', (tester) async {
    final clipboard = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add(
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

    var asked = 0;
    await tester.pumpWidget(
      askBlock(AnswerActionsRow(text: 'the answer', onAskAgain: () => asked++)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('answer-copy')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(clipboard, <String>['the answer']);

    // The tick holds, then gives the copy glyph back.
    await tester.pump(AnswerActionsRow.tick);
    await tester.pump(const Duration(seconds: 4));

    await tester.tap(find.byKey(const ValueKey<String>('answer-ask-again')));
    await tester.pump();
    expect(asked, 1);
  });
}
