import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/motion_budget.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/mark/section_state_glyph.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';

/// The Phase 2 harness.
///
/// It pumps into the **same** repaint-boundary key the amber golden harness
/// uses, so `amberCensus(tester)` works on anything pumped here without a
/// second render — exactly as the Phase 1 harness does.
///
/// It differs from Phase 1's in two ways, and both are forced by what this
/// phase builds: there is a `Localizations` (a real `TextField` asks for one)
/// and there is an `Overlay` (a toast lives in one, and a sheet's route needs a
/// `Navigator`).
const Key phase2BoundaryKey = ValueKey<String>('amber-golden-boundary');

/// Night first, then Day, Veld last — the order the design says to build them
/// in, and therefore the order a failure should be read in.
List<TiqSkin> get phase2Skins => <TiqSkin>[
  TiqSkin.night(density: TiqDensity.field),
  TiqSkin.day(),
  TiqSkin.veld(),
];

TiqSkin phase2SkinNamed(String name) => switch (name) {
  'night.console' => TiqSkin.night(),
  'night.field' => TiqSkin.night(density: TiqDensity.field),
  'day.field' => TiqSkin.day(),
  'day.console' => TiqSkin.day(density: TiqDensity.console),
  'veld' => TiqSkin.veld(),
  _ => throw ArgumentError('No skin named $name'),
};

/// Every skin a Phase 2 component can be built on, in build order.
const List<String> phase2SkinNames = <String>[
  'night.console',
  'night.field',
  'day.field',
  'day.console',
  'veld',
];

/// Pump [child] in [skin], at a pinned size and text scale.
Future<void> pumpPhase2(
  WidgetTester tester, {
  required TiqSkin skin,
  required Widget child,
  Size size = const Size(360, 720),
  double textScale = 1.0,
  List<TorchClaim> claims = const <TorchClaim>[],
  bool navRenders = false,
  bool tabbedRoute = false,
  bool beneathSheet = false,
  bool still = true,
  Locale locale = const Locale('en'),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  addTearDown(TorchSheets.resetForTest);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        devicePixelRatio: 1.0,
        textScaler: TextScaler.linear(textScale),
        // A repeating animation makes `pumpAndSettle` hang forever, and every
        // assertion here is about the resting frame — which is also the frame
        // a reduce-motion reader meets.
        disableAnimations: still,
      ),
      child: Localizations(
        locale: locale,
        delegates: const <LocalizationsDelegate<dynamic>>[
          DefaultWidgetsLocalizations.delegate,
          DefaultMaterialLocalizations.delegate,
        ],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Theme(
            data: ThemeData(extensions: <ThemeExtension<dynamic>>[skin]),
            child: MotionBudgetScope(
              budget: still ? MotionBudget.frozen : MotionBudget.moving,
              child: RepaintBoundary(
                key: phase2BoundaryKey,
                child: ColoredBox(
                  color: skin.palette.ground,
                  child: SizedBox.fromSize(
                    size: size,
                    // THE KEY IS LOAD-BEARING. A `Navigator` element is reused
                    // across pumps and `onGenerateRoute` only ever runs for
                    // the initial route, so without it a second `pumpPhase2`
                    // in the same test keeps rendering the FIRST case — which
                    // would make the census a check on one widget repeated
                    // forty times.
                    child: Navigator(
                      key: ValueKey<int>(identityHashCode(child)),
                      onGenerateRoute: (settings) => PageRouteBuilder<void>(
                        settings: settings,
                        pageBuilder: (context, _, _) => TorchScope(
                          skin: skin,
                          phase: 'phase2',
                          navRenders: navRenders,
                          tabbedRoute: tabbedRoute,
                          beneathSheet: beneathSheet,
                          claims: claims,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// One named state of one component.
typedef Phase2Case = MapEntry<String, Widget>;

/// EVERY STATE OF EVERY PHASE 2 COMPONENT.
///
/// One list, used by the amber census, the 2.0× pass and the Afrikaans pass,
/// so a component cannot be added to one and forgotten by the other two.
///
/// Sheets appear here as their **contents** rather than as pushed routes: the
/// route machinery is tested in `sheet_test.dart`, and what the census needs
/// is the pixels of the thing inside it.
List<Phase2Case> phase2Cases({String? locale}) {
  final af = locale == 'af';
  // Afrikaans runs about 40% longer than English and is the pseudo-
  // localisation CI pass's real-language stand-in.
  String t(String en, String afr) => af ? afr : en;

  final proof = <ProofLine>[
    ProofLine(text: t('6 of 9 sections captured', '6 van 9 afdelings vasgelê')),
    ProofLine(
      text: t('3 photos held on this phone', '3 fotos op hierdie foon gehou'),
      state: SectionState.inProgress,
    ),
    ProofLine(
      text: t('Started 11:04, 41 minutes ago', 'Begin 11:04, 41 minute gelede'),
      state: SectionState.notStarted,
    ),
  ];

  return <Phase2Case>[
    // ── Sheets ──────────────────────────────────────────────────────────
    Phase2Case(
      'TorchSheet',
      TorchSheet(
        title: t('Why are you skipping this?', 'Hoekom slaan jy dit oor?'),
        subtitle: t(
          'This goes to your manager with the route.',
          'Dit gaan saam met die roete na jou bestuurder.',
        ),
        child: Text(t('Body', 'Inhoud')),
      ),
    ),
    Phase2Case('ProofBlock', ProofBlock(lines: proof)),
    Phase2Case('ProofBlock.counting', ProofBlock(lines: proof, counting: true)),
    Phase2Case(
      'DecisionSheet',
      DecisionSheet(
        title: t('You have work here already', 'Jy het reeds werk hier'),
        proof: proof,
        carryOnLabel: t('Carry on from 11:04', 'Gaan voort vanaf 11:04'),
        startOverLabel: t('Start over', 'Begin oor'),
        startOverCost: t(
          'Loses 6 sections and 3 photos',
          'Verloor 6 afdelings en 3 fotos',
        ),
      ),
    ),
    Phase2Case(
      'DecisionSheet.stale',
      DecisionSheet(
        title: t('You have work here already', 'Jy het reeds werk hier'),
        proof: proof,
        stale: true,
        startOverCost: t(
          'Loses 6 sections and 3 photos',
          'Verloor 6 afdelings en 3 fotos',
        ),
      ),
    ),
    Phase2Case(
      'DecisionSheet.counting',
      DecisionSheet(
        title: t('You have work here already', 'Jy het reeds werk hier'),
        proof: proof,
        counting: true,
      ),
    ),
    Phase2Case(
      'ConfirmSheet',
      ConfirmSheet(
        action: t(
          'Delete this alert rule?',
          'Skrap hierdie waarskuwingsreël?',
        ),
        consequences: <String>[
          t('No new alerts will fire.', 'Geen nuwe waarskuwings sal afgaan nie.'),
          t('Open alerts stay open.', 'Oop waarskuwings bly oop.'),
        ],
        record: 'RULE-4471',
        commitLabel: t('Delete rule', 'Skrap reël'),
      ),
    ),
    Phase2Case(
      'SkipReasonPicker',
      SkipReasonPicker(title: t('Why not?', 'Hoekom nie?')),
    ),
    Phase2Case(
      'SkipReasonPicker.threshold',
      SkipReasonPicker(
        title: t('Why not?', 'Hoekom nie?'),
        initial: SkipReason.storeRefused,
        thresholdLine: t(
          'That will be three sections you could not confirm. Your manager '
              'sees that as a store you could not work.',
          'Dit sal drie afdelings wees wat jy nie kon bevestig nie. Jou '
              'bestuurder sien dit as ’n winkel wat jy nie kon werk nie.',
        ),
      ),
    ),
    Phase2Case('SessionEndedSheet', SessionEndedSheet(proof: proof)),
    Phase2Case(
      'SessionHeldLine',
      SessionHeldLine(
        message: t(
          '6 sections and 3 photos are waiting to send.',
          '6 afdelings en 3 fotos wag om te stuur.',
        ),
        actionLabel: t('Sign in', 'Meld aan'),
        onPressed: _noop,
      ),
    ),

    // ── States ──────────────────────────────────────────────────────────
    Phase2Case(
      'Skeleton.rows',
      Skeleton(label: t('outlets', 'winkels'), child: const SkeletonRows()),
    ),
    Phase2Case(
      'Skeleton.panel',
      Skeleton(
        label: t('the scorecard', 'die telkaart'),
        child: SkeletonShell(
          height: 120,
          outlined: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const <Widget>[
              SkeletonLine(role: _title, widthFactor: 0.6),
              SizedBox(height: 8),
              SkeletonLine(role: _meta, widthFactor: 0.35),
            ],
          ),
        ),
      ),
    ),
    for (final drawing in EmptyDrawing.values)
      Phase2Case(
        'EmptyState.${drawing.name}',
        EmptyState(
          drawing: drawing,
          headline: t('No outlets within 2 km', 'Geen winkels binne 2 km nie'),
          body: t(
            'Search by name, or scan a shelf barcode.',
            'Soek op naam, of skandeer ’n rakstrepieskode.',
          ),
          action: TorchSecondaryButton(
            label: t('Search by name', 'Soek op naam'),
            onPressed: _noop,
          ),
        ),
      ),
    Phase2Case(
      'EmptyState.inPanel',
      EmptyState(
        scope: EmptyScope.inPanel,
        headline: t('Nothing triaged yet', 'Nog niks gesorteer nie'),
        body: t('Alerts arrive as visits land.', 'Waarskuwings kom in soos besoeke land.'),
      ),
    ),
    Phase2Case(
      'EmptyState.inline',
      EmptyState(
        scope: EmptyScope.inline,
        headline: t('No held work', 'Geen gehoue werk nie'),
      ),
    ),
    for (final kind in TorchErrorKind.values)
      Phase2Case(
        'ErrorState.${kind.name}',
        ErrorState(
          message: TorchErrorMessage.forKind(kind, code: 'HTTP 503'),
          action: TorchErrorMessage.forKind(kind).offersRetry
              ? TorchSecondaryButton(
                  label: t('Try again', 'Probeer weer'),
                  onPressed: _noop,
                )
              : null,
        ),
      ),
    Phase2Case(
      'ErrorState.inline',
      ErrorState(
        scope: ErrorScope.inline,
        message: TorchErrorMessage.forKind(TorchErrorKind.server),
        attempts: 3,
        action: TorchTertiaryButton(
          label: t('Retry', 'Probeer weer'),
          onPressed: _noop,
        ),
      ),
    ),
    for (final state in SyncState.values)
      Phase2Case(
        'OfflineHeldBanner.${state.name}',
        OfflineHeldBanner(
          state: state,
          count: state == SyncState.offline ? null : 12,
          subtitle: t(
            'They will send themselves · nothing is lost',
            'Hulle stuur hulself · niks gaan verlore nie',
          ),
        ),
      ),
    for (final state in ProgressState.values)
      Phase2Case(
        'TorchProgressBar.${state.name}',
        TorchProgressBar(
          label: t('Visits today', 'Besoeke vandag'),
          value: 14,
          total: state == ProgressState.indeterminate ? null : 20,
          state: state,
        ),
      ),
    Phase2Case(
      'TorchProgressBar.reward',
      TorchProgressBar(
        label: t('Visits today', 'Besoeke vandag'),
        value: 14,
        total: 20,
        milestones: <ProgressMilestone>[
          const ProgressMilestone(at: 10),
          ProgressMilestone(
            at: 20,
            label: t('R500 at 20 visits', 'R500 by 20 besoeke'),
            reward: true,
          ),
        ],
      ),
    ),
    Phase2Case(
      'TorchProgressBar.rewardReached',
      TorchProgressBar(
        label: t('Visits today', 'Besoeke vandag'),
        value: 20,
        total: 20,
        milestones: <ProgressMilestone>[
          ProgressMilestone(
            at: 20,
            label: t('R500 earned', 'R500 verdien'),
            reward: true,
          ),
        ],
      ),
    ),
    for (final kind in ToastKind.values)
      Phase2Case(
        'TorchToast.${kind.name}',
        TorchToast(
          message: t('Visit sent · scored 71', 'Besoek gestuur · telling 71'),
          kind: kind,
          action: TorchTertiaryButton(
            label: t('View', 'Bekyk'),
            onPressed: _noop,
          ),
        ),
      ),
    Phase2Case(
      'PaginationFooter',
      PaginationFooter(
        summary: t(
          'Showing the 20 riskiest of 74.',
          'Wys die 20 riskantstes van 74.',
        ),
        narrowLine: t(
          'Narrow by territory to see the rest.',
          'Verfyn volgens gebied om die res te sien.',
        ),
        unscoredNote: t(
          '6 submitted visits have not been scored yet.',
          '6 ingedien besoeke is nog nie getel nie.',
        ),
      ),
    ),

    // ── Inputs ──────────────────────────────────────────────────────────
    Phase2Case(
      'TorchTextField',
      TorchTextField(
        label: t('What happened?', 'Wat het gebeur?'),
        hint: t('e.g. the fridge was off', 'bv. die yskas was af'),
      ),
    ),
    Phase2Case(
      'TorchTextField.error',
      TorchTextField(
        label: t('What happened?', 'Wat het gebeur?'),
        error: t('Say what happened', 'Sê wat gebeur het'),
      ),
    ),
    Phase2Case(
      'TorchTextField.disabled',
      TorchTextField(
        label: t('What happened?', 'Wat het gebeur?'),
        enabled: false,
        help: t('Locked once submitted', 'Gesluit sodra dit ingedien is'),
      ),
    ),
    Phase2Case(
      'TorchTextField.readOnly',
      TorchTextField(
        label: t('What happened?', 'Wat het gebeur?'),
        readOnly: true,
      ),
    ),
    Phase2Case(
      'TorchNumericField',
      TorchNumericField(label: t('Units on shelf', 'Eenhede op rak')),
    ),
    Phase2Case(
      'TorchNumericField.finding',
      TorchNumericField(
        label: t('Units on shelf', 'Eenhede op rak'),
        controller: TextEditingController(text: '0'),
        zeroIsFinding: true,
        findingWord: t('Out of stock', 'Uit voorraad'),
      ),
    ),
    Phase2Case(
      'CountStepper',
      CountStepper(
        label: t('Units on shelf', 'Eenhede op rak'),
        value: 12,
        unitWord: t('facings', 'front-rye'),
        onChanged: _noopInt,
      ),
    ),
    Phase2Case(
      'CountStepper.notCounted',
      CountStepper(
        label: t('Units on shelf', 'Eenhede op rak'),
        value: null,
        onChanged: _noopInt,
      ),
    ),
    Phase2Case(
      'CountStepper.finding',
      CountStepper(
        label: t('Units on shelf', 'Eenhede op rak'),
        value: 0,
        zeroIsFinding: true,
        findingWord: t('Out of stock', 'Uit voorraad'),
        findingLine: t(
          'Out of stock. This raises a task for the manager.',
          'Uit voorraad. Dit skep ’n taak vir die bestuurder.',
        ),
        onChanged: _noopInt,
      ),
    ),
    Phase2Case(
      'TorchToggle.off',
      TorchToggle(
        label: t('Planogram compliant', 'Voldoen aan planogram'),
        value: false,
        onChanged: _noopBool,
      ),
    ),
    Phase2Case(
      'TorchToggle.on',
      TorchToggle(
        label: t('Fridge working', 'Yskas werk'),
        value: true,
        onChanged: _noopBool,
      ),
    ),
    Phase2Case(
      'TorchCheckbox.unchecked',
      TorchCheckbox(
        label: t('Posters up', 'Plakkate op'),
        value: false,
        onChanged: _noopBool,
      ),
    ),
    Phase2Case(
      'TorchCheckbox.checked',
      TorchCheckbox(
        label: t('Posters up', 'Plakkate op'),
        value: true,
        onChanged: _noopBool,
      ),
    ),
    Phase2Case(
      'ChoiceRow.nothingSelected',
      ChoiceRow<String>(
        label: t('Was the shelf full?', 'Was die rak vol?'),
        value: null,
        onChanged: _noopString,
        options: <ChoiceOption<String>>[
          ChoiceOption<String>(value: 'y', label: t('Yes', 'Ja')),
          ChoiceOption<String>(value: 'n', label: t('No', 'Nee')),
          ChoiceOption<String>(
            value: 'u',
            label: t("Can't tell", 'Kan nie sê'),
          ),
        ],
      ),
    ),
    Phase2Case(
      'ChoiceRow.selected',
      ChoiceRow<String>(
        label: t('Was the shelf full?', 'Was die rak vol?'),
        value: 'y',
        onChanged: _noopString,
        options: <ChoiceOption<String>>[
          ChoiceOption<String>(value: 'y', label: t('Yes', 'Ja')),
          ChoiceOption<String>(value: 'n', label: t('No', 'Nee')),
        ],
      ),
    ),
    Phase2Case(
      'TorchFilterChip',
      TorchFilterChip(
        label: t('Gauteng North', 'Gauteng Noord'),
        selected: false,
        count: 14,
        onSelected: _noop,
      ),
    ),
    Phase2Case(
      'TorchFilterChip.selected',
      TorchFilterChip(
        label: t('Needs a decision', 'Benodig ’n besluit'),
        selected: true,
        count: 5,
        onSelected: _noop,
      ),
    ),
    Phase2Case(
      'TorchFilterRail',
      TorchFilterRail(
        chips: <Widget>[
          TorchFilterChip(
            label: t('All', 'Alles'),
            selected: true,
            onSelected: _noop,
          ),
          TorchFilterChip(
            label: t('Gauteng North', 'Gauteng Noord'),
            selected: false,
            count: 14,
            onSelected: _noop,
          ),
        ],
      ),
    ),
  ];
}

const TiqTypeToken _title = TiqTypeToken(
  name: 'title.m',
  kind: TiqTypeKind.prose,
  size: 16,
  weight: FontWeight.w600,
  height: 1.30,
);

const TiqTypeToken _meta = TiqTypeToken(
  name: 'meta',
  kind: TiqTypeKind.prose,
  size: 12,
  weight: FontWeight.w400,
  height: 1.40,
);

void _noop() {}
void _noopInt(int? _) {}
void _noopBool(bool _) {}
void _noopString(String _) {}
