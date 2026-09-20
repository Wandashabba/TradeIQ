import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/widgets/agent_state_glyph.dart';
import 'package:tradeiq_app/features/agents/data/agents_repository.dart';

void main() {
  // #144's rule: state must differ in SILHOUETTE, not just colour. Every
  // glyph below is painted in the SAME colour on purpose — if this still
  // distinguishes them, colour was never doing the work.
  testWidgets('each state paints a genuinely different shape, same colour throughout', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              AgentStateGlyph(
                key: ValueKey('g-store'),
                state: AgentState.atStore,
                color: Colors.black,
              ),
              AgentStateGlyph(
                key: ValueKey('g-transit'),
                state: AgentState.inTransit,
                color: Colors.black,
              ),
              AgentStateGlyph(
                key: ValueKey('g-idle'),
                state: AgentState.idle,
                color: Colors.black,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Type painterTypeFor(String key) => tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byKey(ValueKey<String>(key)),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter!
        .runtimeType;

    final storeType = painterTypeFor('g-store');
    final transitType = painterTypeFor('g-transit');
    final idleType = painterTypeFor('g-idle');

    expect({storeType, transitType, idleType}, hasLength(3));
    // Ties the shapes to the actual state → painter mapping the widget uses,
    // not just "three distinct types happened to appear".
    expect(storeType, glyphPainterTypeFor(AgentState.atStore));
    expect(transitType, glyphPainterTypeFor(AgentState.inTransit));
    expect(idleType, glyphPainterTypeFor(AgentState.idle));
  });

  group('the at-store pulse', () {
    Widget wrap({required bool reduce}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: const Scaffold(
          body: AgentStateGlyph(
            key: ValueKey('glyph'),
            state: AgentState.atStore,
            color: Colors.black,
            pulse: true,
          ),
        ),
      ),
    );

    testWidgets('renders the still glyph, with no pulse widget built, when reduceMotion is on', (tester) async {
      await tester.pumpWidget(wrap(reduce: true));

      // Advance past where the pulse would otherwise be mid-flight, well
      // under its own 1400ms duration.
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('glyph')),
          matching: find.byType(AnimatedBuilder),
        ),
        findsNothing,
        reason: 'reduceMotion must skip the pulse entirely, not just its '
            'motion — no AnimatedBuilder should ever be built around it',
      );
      // The still shape itself must still be there.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('glyph')),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );

      // If a Ticker were somehow still running (it should never have
      // started), this would never settle — see agent_motion.dart's
      // PulseDot doc comment for exactly this failure mode.
      await tester.pumpAndSettle();
    });

    testWidgets('shows an expand-and-fade halo mid-flight under normal motion, and settles', (tester) async {
      await tester.pumpWidget(wrap(reduce: false));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('glyph')),
          matching: find.byType(AnimatedBuilder),
        ),
        findsOneWidget,
        reason: 'under normal motion the halo should be mid-flight at 400ms '
            'of its 1400ms one-shot duration',
      );

      // The pulse is a ONE-SHOT expand-and-fade, not a perpetual loop (see
      // agent_motion.dart: "nothing repeats forever" — a loop tied to an
      // at-store state that can last hours would never let pumpAndSettle
      // settle). This is the assertion that actually holds that: if the
      // controller were repeating, this call would hang until
      // pumpAndSettle's own timeout.
      await tester.pumpAndSettle();
    });
  });
}
