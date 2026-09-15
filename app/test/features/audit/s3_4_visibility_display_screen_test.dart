import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/agent_kit.dart';
import 'package:tradeiq_app/core/widgets/console.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/core/widgets/photo_capture_field.dart';
import 'package:tradeiq_app/features/audit/data/visibility_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s3_4_visibility_display_screen.dart';

class _SpyVisibilityRepository implements VisibilityRepository {
  String? visitDraftId;
  VisibilityCapture? capture;

  @override
  Future<void> saveVisibility({
    required String visitDraftId,
    required VisibilityCapture capture,
  }) async {
    this.visitDraftId = visitDraftId;
    this.capture = capture;
  }
}

const _bothThemes = ['light', 'dark'];

ThemeData _themeFor(String name) =>
    name == 'light' ? AppTheme.light() : AppTheme.dark();

Widget _screen(VisibilityRepository spy, {ThemeData? theme, Key? key}) =>
    ProviderScope(
      overrides: [visibilityRepositoryProvider.overrideWithValue(spy)],
      child: MaterialApp(
        theme: theme,
        // A fresh key per theme pass on BOTH the section (so its form State
        // never carries) and the scroll view (so its scroll offset resets —
        // otherwise the second pass starts scrolled down and top-of-list taps
        // miss).
        home: Scaffold(
          body: SingleChildScrollView(
            key: key,
            child: S3S4VisibilityDisplayScreen(key: key, visitDraftId: 'v1'),
          ),
        ),
      ),
    );

void main() {
  testWidgets(
    'captures visibility and calls saveVisibility on Save — branding via '
    'AgentCheck, high-traffic via AgentToggle',
    (tester) async {
      for (final name in _bothThemes) {
        final spy = _SpyVisibilityRepository();

        await tester.pumpWidget(
          _screen(spy, theme: _themeFor(name), key: ValueKey(name)),
        );
        await tester.pumpAndSettle();

        // Branding present is now an AgentCheck row — the key is preserved, so
        // tapping it still flips the value.
        await tester.tap(find.byKey(const ValueKey('branding-poster')));
        await tester.enterText(find.byKey(const ValueKey('planogram')), '82.5');
        await tester.enterText(find.byKey(const ValueKey('facings')), '12');
        await tester.enterText(find.byKey(const ValueKey('cleanliness')), '90');
        // High-traffic is now an AgentToggle — tap the row by its label, not a
        // 20px SwitchListTile.
        await tester.ensureVisible(find.text('High-traffic location'));
        await tester.tap(find.text('High-traffic location'));
        await tester.pump();

        await tester.ensureVisible(find.text('Save visibility'));
        await tester.tap(find.text('Save visibility'));
        await tester.pumpAndSettle();

        expect(spy.visitDraftId, 'v1', reason: name);
        expect(spy.capture!.planogramCompliancePct, 82.5, reason: name);
        expect(spy.capture!.facingsCount, 12, reason: name);
        expect(spy.capture!.cleanlinessScore, 90, reason: name);
        expect(spy.capture!.highTrafficPass, true, reason: name);
        expect(spy.capture!.brandingElements['poster'], true, reason: name);
        expect(
          find.text('Visibility saved — queued for sync'),
          findsOneWidget,
          reason: name,
        );
      }
    },
  );

  testWidgets(
    'branding rows are AgentChecks, high-traffic is an AgentToggle, inputs are '
    'AgentFields on a PanelCard, save is an AgentButton — no raw '
    'Card/CheckboxListTile/SwitchListTile/ElevatedButton',
    (tester) async {
      for (final name in _bothThemes) {
        await tester.pumpWidget(
          _screen(
            _SpyVisibilityRepository(),
            theme: _themeFor(name),
            key: ValueKey(name),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Card), findsNothing, reason: '$name no Card');
        expect(
          find.byType(CheckboxListTile),
          findsNothing,
          reason: '$name no CheckboxListTile',
        );
        expect(
          find.byType(SwitchListTile),
          findsNothing,
          reason: '$name no SwitchListTile',
        );
        expect(
          find.byType(ElevatedButton),
          findsNothing,
          reason: '$name no ElevatedButton',
        );

        // The three branding options are AgentChecks; the high-traffic setting
        // is an AgentToggle; the three measurements are labelled AgentFields;
        // they sit on a console PanelCard; the save is the kit's button.
        expect(
          find.byType(AgentCheck),
          findsNWidgets(3),
          reason: '$name three AgentChecks',
        );
        expect(
          find.widgetWithText(AgentToggle, 'High-traffic location'),
          findsOneWidget,
          reason: '$name high-traffic AgentToggle',
        );
        expect(
          find.byType(AgentField),
          findsNWidgets(3),
          reason: '$name three AgentFields',
        );
        final glass = tester
            .element(find.byType(S3S4VisibilityDisplayScreen))
            .colors
            .glass;
        if (glass) {
          // Lumen Glass: one no-blur tile per question group — branding,
          // measurements, placement — rather than one long console panel.
          final tile = find.byWidgetPredicate(
            (w) => w is GlassPane && w.kind == GlassKind.tile && !w.blur,
          );
          expect(
            find.byType(PanelCard),
            findsNothing,
            reason: '$name no panel',
          );
          // Each group on its OWN tile. Counted per group rather than in total:
          // the shared photo field frames itself in a tile of its own.
          final tiles = <Element>{};
          for (final label in [
            'BRANDING ELEMENTS PRESENT',
            'Facings count',
            'High-traffic location',
          ]) {
            final own = find.ancestor(of: find.text(label), matching: tile);
            expect(own, findsOneWidget, reason: '$name "$label" on a tile');
            tiles.add(tester.element(own));
          }
          expect(tiles, hasLength(3), reason: '$name three separate tiles');
        } else {
          expect(find.byType(PanelCard), findsOneWidget, reason: '$name panel');
        }
        expect(
          find.widgetWithText(AgentButton, 'Save visibility'),
          findsOneWidget,
          reason: '$name save is AgentButton',
        );
      }
    },
  );

  testWidgets(
    'the shelf photo capture field is preserved and renders in both themes',
    (tester) async {
      for (final name in _bothThemes) {
        await tester.pumpWidget(
          _screen(
            _SpyVisibilityRepository(),
            theme: _themeFor(name),
            key: ValueKey(name),
          ),
        );
        await tester.pumpAndSettle();

        // The evidence capture — wired to queuePhoto(section: 'visibility') —
        // must survive the console rebuild. (The section string itself is
        // guarded by the source-literal test below; here we prove the field
        // still renders with its label intact.)
        expect(
          find.byType(PhotoCaptureField),
          findsOneWidget,
          reason: '$name photo field present',
        );
        expect(
          tester
              .widget<PhotoCaptureField>(find.byType(PhotoCaptureField))
              .label,
          'Shelf photo',
          reason: '$name label',
        );
      }
    },
  );

  test('no non-geometry AppColors. remain in the S3-4 visibility source', () {
    final src = File(
      'lib/features/audit/presentation/sections/s3_4_visibility_display_screen.dart',
    ).readAsStringSync();
    final offenders = RegExp(
      r'AppColors\.(?!radiusPanel|radiusControl)\w+',
    ).allMatches(src).map((m) => m.group(0)).toSet().toList();
    expect(offenders, isEmpty, reason: 'use context.colors for: $offenders');
  });

  test('the shelf photo is queued under section: visibility', () {
    // The section string is the evidence-linkage key that later joins this
    // photo to the visibility section on the manager side. Nothing in the
    // widget tests captures a photo, so queuePhoto(section:) is never exercised
    // at runtime — this source-literal guard is what catches a silent flip to
    // e.g. 'pricing', which would misfile the evidence with the whole suite
    // still green.
    final src = File(
      'lib/features/audit/presentation/sections/s3_4_visibility_display_screen.dart',
    ).readAsStringSync();
    expect(src, contains("section: 'visibility'"));
  });
}
