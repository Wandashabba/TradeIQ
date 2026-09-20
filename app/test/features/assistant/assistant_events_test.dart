import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/assistant/data/assistant_events.dart';

/// Build one SSE frame the way the server writes it.
String frame(String event, String data) => 'event: $event\ndata: $data\n\n';

void main() {
  group('AssistantEvent.parse', () {
    test('reads a token', () {
      final event = AssistantEvent.parse('token', '{"text":"hello"}');
      expect(event, isA<TokenEvent>());
      expect((event! as TokenEvent).text, 'hello');
    });

    test('reads tool_start with its pillar', () {
      final event = AssistantEvent.parse(
        'tool_start',
        '{"name":"getStockLevels","pillar":"stock"}',
      );
      expect((event! as ToolStartEvent).pillar, 'stock');
    });

    test('reads an artifact', () {
      final event = AssistantEvent.parse(
        'artifact',
        '{"id":"a1","type":"agent_scorecard","params":{},"data":{"averageScore":82}}',
      );
      final artifact = event! as ArtifactEvent;
      expect(artifact.id, 'a1');
      expect(artifact.type, 'agent_scorecard');
      expect((artifact.data as Map)['averageScore'], 82);
    });

    test('reads the conversation id the server mints', () {
      final event = AssistantEvent.parse('conversation', '{"id":"conv-7"}');
      expect((event! as ConversationEvent).id, 'conv-7');
    });

    test('drops a conversation frame with no id', () {
      // Nothing to echo back, and storing a null would look like a first turn
      // forever. Better to keep the id we already have.
      expect(AssistantEvent.parse('conversation', '{}'), isNull);
    });

    test('ignores an unknown event type rather than throwing', () {
      // The contract that lets the server add events without a lockstep app
      // release. A client that threw here would turn every additive server
      // change into a forced update.
      expect(AssistantEvent.parse('some_future_event', '{"x":1}'), isNull);
    });

    test('ignores a frame whose payload will not parse', () {
      // A malformed frame mid-stream should drop that frame, not kill a turn
      // the user is watching.
      expect(AssistantEvent.parse('token', 'not json'), isNull);
    });

    test('ignores a payload that is not an object', () {
      expect(AssistantEvent.parse('token', '"just a string"'), isNull);
    });

    test('tolerates a missing field rather than throwing', () {
      final event = AssistantEvent.parse('tool_end', '{}');
      expect((event! as ToolEndEvent).ok, isFalse);
    });

    test('rejects an artifact with no id or type', () {
      expect(AssistantEvent.parse('artifact', '{"data":{}}'), isNull);
    });

    group('sources', () {
      test('reads valid sources in order', () {
        final event = AssistantEvent.parse('sources', '''{"sources":[
          {"title":"Shoprite launches new stores","url":"https://www.iol.co.za/business/shoprite","domain":"iol.co.za","pageAge":"3 days ago","retrievedAt":"2026-09-17T10:12:00.000Z","snippet":"Shoprite said on Monday ..."},
          {"title":"Retail slows","url":"http://example.com/a","domain":"example.com","pageAge":null,"retrievedAt":"2026-09-17T10:12:00.000Z","snippet":null}
        ]}''');
        final sources = (event! as SourcesEvent).sources;
        expect(sources, hasLength(2));
        final first = sources.first;
        expect(first.title, 'Shoprite launches new stores');
        expect(first.url, Uri.parse('https://www.iol.co.za/business/shoprite'));
        expect(first.domain, 'iol.co.za');
        expect(first.pageAge, '3 days ago');
        expect(first.retrievedAt, DateTime.utc(2026, 9, 17, 10, 12));
        expect(first.snippet, 'Shoprite said on Monday ...');
        expect(sources[1].url.scheme, 'http');
        expect(sources[1].pageAge, isNull);
        expect(sources[1].snippet, isNull);
      });

      test('drops anything that is not http or https', () {
        final event = AssistantEvent.parse('sources', '''{"sources":[
          {"title":"a","url":"javascript:alert(1)","domain":"x"},
          {"title":"b","url":"data:text/html,<b>hi</b>","domain":"x"},
          {"title":"c","url":"ftp://files.example.com/x","domain":"x"},
          {"title":"d","url":"JAVASCRIPT:alert(1)","domain":"x"},
          {"title":"e","url":"/relative/path","domain":"x"},
          {"title":"f","url":"https://ok.example.com/","domain":"ok.example.com"}
        ]}''');
        final sources = (event! as SourcesEvent).sources;
        expect(sources.map((s) => s.title), ['f']);
      });

      test('skips malformed entries rather than failing the frame', () {
        final event = AssistantEvent.parse('sources', '''{"sources":[
          "not an object",
          null,
          {"url":"https://no-title.example.com/"},
          {"title":"","url":"https://empty-title.example.com/"},
          {"title":"no url"},
          {"title":7,"url":"https://wrong-type.example.com/"},
          {"title":"Kept","url":"https://www.kept.example.com/a"}
        ]}''');
        final sources = (event! as SourcesEvent).sources;
        expect(sources, hasLength(1));
        // Missing optional fields are fine; domain falls back to the host.
        expect(sources.single.domain, 'kept.example.com');
        expect(sources.single.pageAge, isNull);
        expect(sources.single.retrievedAt, isNull);
        expect(sources.single.snippet, isNull);
      });

      test('a missing or wrong-typed list is an empty event', () {
        expect(
          (AssistantEvent.parse('sources', '{}')! as SourcesEvent).sources,
          isEmpty,
        );
        expect(
          (AssistantEvent.parse('sources', '{"sources":"x"}')! as SourcesEvent)
              .sources,
          isEmpty,
        );
      });

      test('caps at ten', () {
        final entries = List.generate(
          14,
          (i) => '{"title":"t$i","url":"https://e.com/$i","domain":"e.com"}',
        ).join(',');
        final event = AssistantEvent.parse('sources', '{"sources":[$entries]}');
        expect((event! as SourcesEvent).sources, hasLength(10));
      });
    });
  });

  group('SseParser', () {
    test('parses whole frames', () {
      final parser = SseParser();
      final events = parser.add(
        frame('token', '{"text":"a"}') + frame('done', '{}'),
      );
      expect(events.map((e) => e.runtimeType).toList(), [
        TokenEvent,
        DoneEvent,
      ]);
    });

    test('buffers a frame split across chunks', () {
      // The failure that only shows up against a real server: chunks split
      // wherever the network decides, including mid-frame.
      final parser = SseParser();
      expect(parser.add('event: token\ndata: {"te'), isEmpty);
      final events = parser.add('xt":"hello"}\n\n');
      expect(events, hasLength(1));
      expect((events.first as TokenEvent).text, 'hello');
    });

    test('buffers a split between the event and data lines', () {
      final parser = SseParser();
      expect(parser.add('event: token\n'), isEmpty);
      final events = parser.add('data: {"text":"x"}\n\n');
      expect(events, hasLength(1));
    });

    test('handles many frames arriving in one chunk', () {
      final parser = SseParser();
      final events = parser.add(
        frame('tool_start', '{"name":"t","pillar":"stock"}') +
            frame('tool_end', '{"name":"t","ok":true}') +
            frame('token', '{"text":"done"}'),
      );
      expect(events, hasLength(3));
    });

    test('handles one character at a time', () {
      // The pathological boundary case. If the buffer logic is wrong anywhere,
      // this is what catches it.
      final parser = SseParser();
      final source = frame('token', '{"text":"streamed"}');
      final events = <AssistantEvent>[];
      for (final char in source.split('')) {
        events.addAll(parser.add(char));
      }
      expect(events, hasLength(1));
      expect((events.first as TokenEvent).text, 'streamed');
    });

    test('keeps a trailing partial frame buffered', () {
      final parser = SseParser();
      final events = parser.add(
        '${frame('token', '{"text":"a"}')}event: token\ndata: {"text":"b"',
      );
      expect(events, hasLength(1));
      // The second frame completes on the next chunk, not this one.
      expect(parser.add('}\n\n'), hasLength(1));
    });

    test('survives a token containing a newline', () {
      // Narrative text has paragraphs. The frame delimiter is a BLANK line, so
      // a single newline inside the JSON payload must not split a frame — and
      // the server JSON-encodes it, which is what makes that true.
      final parser = SseParser();
      final events = parser.add(
        frame('token', '{"text":"line one\\nline two"}'),
      );
      expect((events.first as TokenEvent).text, 'line one\nline two');
    });

    test('drops an unknown event without disturbing the ones around it', () {
      final parser = SseParser();
      final events = parser.add(
        frame('token', '{"text":"a"}') +
            frame('future_thing', '{"x":1}') +
            frame('done', '{}'),
      );
      expect(events.map((e) => e.runtimeType).toList(), [
        TokenEvent,
        DoneEvent,
      ]);
    });
  });
}
