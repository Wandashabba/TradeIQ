import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/assistant/answer/answer_markdown.dart';

ParsedAnswer done(String s) => parseAnswer(s, streaming: false);
ParsedAnswer live(String s) => parseAnswer(s, streaming: true);

String visible(String s, {required bool streaming}) =>
    plainInline(s, streaming: streaming);

const _mockupAnswer = '''Gauteng is **down 12.4%** on last August, and Soweto is most of the story.

> **What explains it**
> The **500ml Kalahari Cola** was out of stock at **5 of Soweto's 8 outlets** for 9 days.

#### What I'd do
- **Restock the 500ml** at those five Soweto outlets first.
- Ask *Lerato Mahlangu* why the gap wasn't flagged.

1. First
2. Second

```followups
Show Soweto outlets on a map
Which agents cover Soweto?
Compare with Western Cape
```''';

void main() {
  group('blocks', () {
    test('the full answer shape parses into its blocks', () {
      final parsed = done(_mockupAnswer);
      final kinds = parsed.blocks.map((b) => b.kind).toList();
      expect(kinds, [
        AnswerBlockKind.paragraph,
        AnswerBlockKind.quote,
        AnswerBlockKind.heading,
        AnswerBlockKind.bullets,
        AnswerBlockKind.numbered,
      ]);
      expect(parsed.hasMarkdown, isTrue);
      expect(parsed.headline!.text, startsWith('Gauteng is'));
      expect(parsed.blocks[2].level, 4);
      expect(parsed.blocks[2].text, "What I'd do");
      expect(parsed.blocks[3].items, hasLength(2));
      expect(parsed.blocks[4].items, ['First', 'Second']);
    });

    test('### and #### are headings at their level', () {
      final parsed = done('### Three\n#### Four');
      expect(parsed.blocks.map((b) => (b.kind, b.level)), [
        (AnswerBlockKind.heading, 3),
        (AnswerBlockKind.heading, 4),
      ]);
    });

    test('a list straight after a paragraph line still starts a list', () {
      final parsed = done('What to do:\n- one\n- two');
      expect(parsed.blocks.map((b) => b.kind), [
        AnswerBlockKind.paragraph,
        AnswerBlockKind.bullets,
      ]);
    });

    test('an indented line continues its list item', () {
      final parsed = done('- one\n  more of one\n- two');
      expect(parsed.blocks.single.items, ['one more of one', 'two']);
    });

    test('the headline is only a first paragraph', () {
      expect(done('#### Heading first\n\nThen prose.').headline, isNull);
      expect(done('Prose first.\n\nMore.').headline!.text, 'Prose first.');
    });

    test('a long first paragraph is body text, not a headline', () {
      final long = 'The **quarter** ${'went broadly to plan across the region ' * 6}.';
      expect(done('$long\n\n- one').headline, isNull);
      expect(done('Short **headline**.\n\n- one').headline, isNotNull);
    });

    test('plain text is not markdown', () {
      final parsed = done('Tumo is up 6 points.\n\nThat is 5 * 3 better.');
      expect(parsed.hasMarkdown, isFalse);
      expect(parsed.followUps, isEmpty);
    });

    test('snake_case is not emphasis, and not markdown', () {
      expect(done('the outlet_id column').hasMarkdown, isFalse);
      expect(visible('the outlet_id column', streaming: false),
          'the outlet_id column');
    });
  });

  group('blockquote callout', () {
    test('a bold first line is the kicker', () {
      final quote = done('> **What explains it**\n> The cola ran out.')
          .blocks
          .single;
      expect(quote.kind, AnswerBlockKind.quote);
      expect(quote.kicker, 'What explains it');
      expect(quote.text, 'The cola ran out.');
    });

    test('without a bold first line there is no kicker', () {
      final quote = done('> The cola ran out at **5 outlets**.').blocks.single;
      expect(quote.kicker, isNull);
      expect(quote.text, 'The cola ran out at **5 outlets**.');
    });

    test('bold that does not fill the first line is body, not kicker', () {
      final quote = done('> **Cola** ran out.').blocks.single;
      expect(quote.kicker, isNull);
    });

    test('a kicker still being written is shown as a kicker', () {
      final quote = live('> **What expl').blocks.single;
      expect(quote.kicker, 'What expl');
      expect(quote.text, isEmpty);
    });
  });

  group('followups fence', () {
    test('parses one question per non-empty line and strips the block', () {
      final parsed = done('Answer.\n\n```followups\nOne?\n\n  Two?  \n```');
      expect(parsed.followUps, ['One?', 'Two?']);
      expect(parsed.blocks.single.text, 'Answer.');
    });

    test('is capped at three', () {
      final parsed = done('```followups\na\nb\nc\nd\ne\n```');
      expect(parsed.followUps, ['a', 'b', 'c']);
    });

    test('is hidden while unclosed and streaming', () {
      for (final partial in [
        'Answer.\n\n`',
        'Answer.\n\n``',
        'Answer.\n\n```',
        'Answer.\n\n```follow',
        'Answer.\n\n```followups\nShow Soweto',
        'Answer.\n\n```followups\nShow Soweto\nWhich agents?\n``',
      ]) {
        final parsed = live(partial);
        expect(parsed.followUps, isEmpty, reason: partial);
        expect(parsed.blocks.single.text, 'Answer.', reason: partial);
        for (final block in parsed.blocks) {
          expect(block.text, isNot(contains('`')), reason: partial);
        }
      }
    });

    test('closing the fence mid-stream turns it into chips', () {
      final parsed = live('Answer.\n\n```followups\nOne?\nTwo?\n```');
      expect(parsed.followUps, ['One?', 'Two?']);
    });

    test('an unclosed fence at the end of the turn is still read', () {
      expect(done('Answer.\n\n```followups\nOne?').followUps, ['One?']);
    });

    test('any other closed fence is a code block', () {
      final parsed = done('```\nx = 1\n```');
      expect(parsed.blocks.single.kind, AnswerBlockKind.code);
      expect(parsed.blocks.single.text, 'x = 1');
    });
  });

  group('inline', () {
    test('bold, italic and code resolve to styled runs', () {
      expect(parseInline('a **b** *c* `d` __e__ _f_', streaming: false), [
        const InlineRun('a '),
        const InlineRun('b', bold: true),
        const InlineRun(' '),
        const InlineRun('c', italic: true),
        const InlineRun(' '),
        const InlineRun('d', code: true),
        const InlineRun(' '),
        const InlineRun('e', bold: true),
        const InlineRun(' '),
        const InlineRun('f', italic: true),
      ]);
    });

    test('italic nests inside bold', () {
      expect(parseInline('**a *b* c**', streaming: false), [
        const InlineRun('a ', bold: true),
        const InlineRun('b', bold: true, italic: true),
        const InlineRun(' c', bold: true),
      ]);
    });

    test('no raw markers remain once a construct closes', () {
      const text = 'Gauteng is **down 12.4%**, `sku_500` and *Soweto*.';
      final shown = visible(text, streaming: true);
      expect(shown, 'Gauteng is down 12.4%, sku_500 and Soweto.');
      expect(visible(text, streaming: false), shown);
    });

    test('an unfinished marker mid-stream is hidden, not printed', () {
      expect(visible('Gauteng is **down 12', streaming: true),
          'Gauteng is down 12');
      expect(parseInline('Gauteng is **down 12', streaming: true).last,
          const InlineRun('down 12', bold: true));
      expect(visible('Gauteng is *', streaming: true), 'Gauteng is ');
      expect(visible('Gauteng is **', streaming: true), 'Gauteng is ');
      expect(visible('Use `sku_5', streaming: true), 'Use sku_5');
    });

    test('an unclosed marker once the turn is over is printed as written', () {
      expect(visible('5 **x', streaming: false), '5 **x');
      expect(visible('a ` b', streaming: false), 'a ` b');
    });

    test('a spaced asterisk is arithmetic, not emphasis', () {
      expect(visible('5 * 3 = 15', streaming: true), '5 * 3 = 15');
      expect(visible('5 * 3 = 15', streaming: false), '5 * 3 = 15');
    });
  });

  group('streaming never throws', () {
    test('every prefix of a full answer parses', () {
      for (var i = 0; i <= _mockupAnswer.length; i++) {
        final prefix = _mockupAnswer.substring(0, i);
        final parsed = live(prefix);
        for (final block in parsed.blocks) {
          for (final text in [block.text, ...block.items]) {
            parseInline(text, streaming: true);
          }
        }
        expect(parsed.followUps.length, lessThanOrEqualTo(3));
      }
    });

    test('a half-written list or heading line is held back', () {
      expect(live('Answer.\n\n-').blocks.single.text, 'Answer.');
      expect(live('Answer.\n\n####').blocks.single.text, 'Answer.');
      expect(live('Answer.\n\n1.').blocks.single.text, 'Answer.');
      expect(live('Answer.\n- ').blocks.single.kind, AnswerBlockKind.paragraph);
      expect(live('Answer.\n- a').blocks.last.kind, AnswerBlockKind.bullets);
    });

    test('garbage does not throw', () {
      for (final junk in ['', '\n\n', '***', '```', '>', '> **', '_', '`', '**_*`']) {
        expect(() => done(junk), returnsNormally, reason: junk);
        expect(() => live(junk), returnsNormally, reason: junk);
        expect(() => parseInline(junk, streaming: true), returnsNormally);
        expect(() => parseInline(junk, streaming: false), returnsNormally);
      }
    });
  });
}
