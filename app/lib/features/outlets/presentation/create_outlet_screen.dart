import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/location/location_service.dart';
import '../../../core/theme/torchlight/console_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../../territories/data/territories_repository.dart';
import '../data/outlets_repository.dart';
import 'outlet_coordinates.dart';

/// ADD A STORE — and where it is, typed rather than assumed (#386).
///
/// ```text
///   ← Stores
///   Add a store
///   ── Where this store is ─────────────────────
///   Seeded from this phone. Type over it if you
///   are not standing in the store.
///   Latitude
///   ┌────────────────────────────────┐
///   │ -26.20410                      │
///   └────────────────────────────────┘
///   Between -90 and 90. Johannesburg is about -26,2.
///   ── This store ──────────────────────────────
///   Store name   Store code   Channel   Territory
///   [ ☾ ]  [        Add the store        ]
/// ```
///
/// ## The phone seeds the pin; it does not set it
///
/// `getCurrentPosition()` used to BE the coordinates, with no field to
/// override them. A manager onboarding forty stores from the depot on a Monday
/// pinned forty stores to the depot car park — and until `PATCH /outlets/:id`
/// existed, no screen in the product could correct a single one of them. The
/// fields are editable, they are the source of truth on submit, and the
/// location block says in words that what it found is a seed.
///
/// ## The amber, counted
///
/// Not a tab root — a manager came here to add one store and leave — so the
/// nav takes no slot and the thumb zone carries the one commit. Night's two
/// content grants go to **one** object, "Add the store"; Day and Veld light
/// the same block and nothing else. With the keyboard up the nav is gone
/// anyway, so a focused field plus the lit primary is still inside the budget.
class CreateOutletScreen extends ConsumerWidget {
  const CreateOutletScreen({super.key});

  /// "Add the store". Rung 1, and the only claim this route makes.
  static const String submitClaimId = 'create-outlet-submit';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ConsoleTorchlightRoute(child: _CreateOutlet());
  }
}

class _CreateOutlet extends ConsumerStatefulWidget {
  const _CreateOutlet();

  @override
  ConsumerState<_CreateOutlet> createState() => _CreateOutletState();
}

class _CreateOutletState extends ConsumerState<_CreateOutlet> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _channelCtrl = TextEditingController();

  /// The coordinates that will actually be sent (#386). The device position
  /// seeds these and nothing more.
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();

  /// The chosen territory's **code**, which is what `Outlet.territoryId`
  /// stores. Held as a selection rather than typed text: this was a free field
  /// defaulted to 'gauteng-north', and it invited exactly the mistake it got —
  /// a store filed under the territory's *name* while the column wanted its
  /// code, leaving the outlet absent from every territory-scoped view with no
  /// error to explain it.
  String? _territoryCode;

  bool _locating = false;
  bool _submitting = false;

  /// Which sentence the location block is telling, or null while it has not
  /// tried yet.
  _LocationOutcome? _outcome;

  /// Per-field refusals, shown under the field they belong to rather than in a
  /// snack bar that covers the thing it is complaining about.
  final Map<String, String> _errors = <String, String>{};

  @override
  void initState() {
    super.initState();
    // A controller's text is the form's state, so the submit gate has to
    // rebuild when any of them changes.
    for (final controller in <TextEditingController>[
      _nameCtrl,
      _codeCtrl,
      _channelCtrl,
      _latCtrl,
      _lngCtrl,
    ]) {
      controller.addListener(_onTyped);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchLocation());
  }

  void _onTyped() => setState(() {});

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _nameCtrl,
      _codeCtrl,
      _channelCtrl,
      _latCtrl,
      _lngCtrl,
    ]) {
      controller
        ..removeListener(_onTyped)
        ..dispose();
    }
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _locating = true;
      _outcome = null;
    });
    final result = await ref.read(locationServiceProvider).getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (result is LocationGranted) {
        _outcome = _LocationOutcome.found;
        // Seeded, not locked. A manager standing in the store keeps what the
        // phone found; one sitting at the depot types the real numbers over
        // it.
        _latCtrl.text = result.lat.toString();
        _lngCtrl.text = result.lng.toString();
      } else if (result is LocationDenied) {
        _outcome = _LocationOutcome.denied;
      } else {
        _outcome = _LocationOutcome.failed;
      }
    });
  }

  /// Everything the server needs, or null with [_errors] filled in.
  Map<String, String>? _validate(AppLocalizations l10n) {
    final errors = <String, String>{};
    String need(String key, TextEditingController controller) {
      final text = controller.text.trim();
      if (text.isEmpty) errors[key] = l10n.outletRequired;
      return text;
    }

    final name = need('name', _nameCtrl);
    final code = need('code', _codeCtrl);
    final channel = need('channel', _channelCtrl);
    final lat = validateCoordinate(l10n, _latCtrl.text, latitude: true);
    final lng = validateCoordinate(l10n, _lngCtrl.text, latitude: false);
    if (lat != null) errors['lat'] = lat;
    if (lng != null) errors['lng'] = lng;
    if (_territoryCode == null) {
      errors['territory'] = l10n.createOutletTerritoryNotChosen;
    }

    if (errors.isNotEmpty) {
      setState(
        () => _errors
          ..clear()
          ..addAll(errors),
      );
      return null;
    }
    setState(_errors.clear);
    return <String, String>{
      'name': name,
      'code': code,
      'channel': channel,
      'lat': _latCtrl.text.trim(),
      'lng': _lngCtrl.text.trim(),
    };
  }

  /// Whether every required value is present. The button is armed on this and
  /// nothing else: a primary that is lit and refuses is a primary nobody
  /// trusts.
  bool get _complete =>
      _nameCtrl.text.trim().isNotEmpty &&
      _codeCtrl.text.trim().isNotEmpty &&
      _channelCtrl.text.trim().isNotEmpty &&
      _territoryCode != null &&
      double.tryParse(_latCtrl.text.trim()) != null &&
      double.tryParse(_lngCtrl.text.trim()) != null;

  Future<void> _submit() async {
    final l10n = context.l10n;
    final values = _validate(l10n);
    if (values == null) return;

    setState(() => _submitting = true);
    final bool created;
    try {
      await ref
          .read(outletsRepositoryProvider)
          .createOutlet(
            name: values['name']!,
            code: values['code']!,
            channelType: values['channel']!,
            // The typed fields are the source of truth, not what the phone
            // found — so a store can be created with the right coordinates
            // even when the phone never got a fix, which is the whole point of
            // the fields being editable.
            lat: double.parse(values['lat']!),
            lng: double.parse(values['lng']!),
            territoryId: _territoryCode!,
          );
      ref.invalidate(outletsListProvider);
      created = true;
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      // Sanitised: a `catch` object in a toast is how a host name reaches a
      // screenshot in a WhatsApp group.
      showTorchToast(
        context,
        message: l10n.createOutletFailed,
        kind: ToastKind.failure,
      );
      return;
    }
    if (!mounted) return;
    // The busy state is cleared whether or not there is anywhere to go. A
    // screen reached by a deep link with nothing behind it used to sit on a
    // spinner for ever after a store had been created perfectly well.
    setState(() => _submitting = false);
    // Leaving is NOT inside the try. A router that refuses to pop would
    // otherwise be caught by the failure arm and reported as "nothing was
    // saved" for a store that was saved.
    if (created && context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final territories = ref.watch(territoriesListProvider);

    return TorchScope(
      skin: skin,
      phase: _submitting ? 'submitting' : 'form',
      navRenders: false,
      tabbedRoute: false,
      claims: <TorchClaim>[
        TorchPrimaryButton.claim(CreateOutletScreen.submitClaimId),
      ],
      child: TorchShell(
        profile: TorchShellProfile.console,
        header: TorchAppHeader(
          title: l10n.createOutletTitle,
          back: TorchIconButton(
            icon: Icons.arrow_back,
            // A destination, never "Back".
            semanticLabel: l10n.createOutletBack,
            onPressed: () => context.pop(),
          ),
        ),
        skinCycle: const ConsoleSkinCycle(),
        primary: TorchPrimaryButton(
          key: const ValueKey<String>('create-outlet-submit'),
          label: l10n.createOutletSubmit,
          claimId: CreateOutletScreen.submitClaimId,
          busy: _submitting,
          blockedReason: _complete ? null : l10n.createOutletBlocked,
          onPressed: _complete && !_submitting ? _submit : null,
        ),
        children: <Widget>[
          SectionRule(l10n.createOutletLocationHeading),
          const SizedBox(height: TiqSpace.s4),
          _LocationLine(
            locating: _locating,
            outcome: _outcome,
            onRetry: _fetchLocation,
          ),
          const SizedBox(height: TiqSpace.s5),
          TorchTextField(
            key: const ValueKey<String>('create-outlet-lat'),
            label: l10n.outletFieldLatitude,
            controller: _latCtrl,
            help: l10n.outletFieldLatitudeHelp,
            error: _errors['lat'],
            keyboardType: coordinateKeyboard,
            autocorrect: false,
            identifier: true,
          ),
          const SizedBox(height: TiqSpace.s5),
          TorchTextField(
            key: const ValueKey<String>('create-outlet-lng'),
            label: l10n.outletFieldLongitude,
            controller: _lngCtrl,
            help: l10n.outletFieldLongitudeHelp,
            error: _errors['lng'],
            keyboardType: coordinateKeyboard,
            autocorrect: false,
            identifier: true,
          ),
          const SizedBox(height: TiqSpace.s7),

          SectionRule(l10n.outletDetailFormHeading),
          const SizedBox(height: TiqSpace.s4),
          TorchTextField(
            key: const ValueKey<String>('create-outlet-name'),
            label: l10n.outletFieldName,
            controller: _nameCtrl,
            error: _errors['name'],
          ),
          const SizedBox(height: TiqSpace.s5),
          TorchTextField(
            key: const ValueKey<String>('create-outlet-code'),
            label: l10n.outletFieldCode,
            controller: _codeCtrl,
            error: _errors['code'],
            autocorrect: false,
            identifier: true,
          ),
          const SizedBox(height: TiqSpace.s5),
          TorchTextField(
            key: const ValueKey<String>('create-outlet-channel'),
            label: l10n.outletFieldChannel,
            controller: _channelCtrl,
            help: l10n.outletFieldChannelHelp,
            error: _errors['channel'],
          ),
          const SizedBox(height: TiqSpace.s5),
          // Names on screen, codes on the wire. A manager knows the store is
          // in "Gauteng North"; nobody memorises that its code is
          // 'gauteng-north' — still less '2773u'.
          territories.when(
            loading: () => Skeleton(
              label: l10n.outletFieldTerritory,
              child: const SkeletonShell(height: 72, outlined: true),
            ),
            error: (error, stack) => ErrorState(
              scope: ErrorScope.inline,
              message: TorchErrorMessage(
                kind: TorchErrorKind.unknown,
                headline: l10n.createOutletTerritoriesFailed,
                body: l10n.createOutletNoTerritories,
                offersRetry: true,
              ),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('territories-retry'),
                label: l10n.createOutletTerritoriesRetry,
                onPressed: () => ref.invalidate(territoriesListProvider),
              ),
            ),
            data: (list) => TorchPickerField<String>(
              key: const ValueKey<String>('territory-picker'),
              label: l10n.outletFieldTerritory,
              value: _territoryCode,
              options: <PickerOption<String>>[
                for (final territory in list)
                  PickerOption<String>(
                    value: territory.code,
                    label: territory.name,
                    identifier: territory.code,
                  ),
              ],
              notChosenLine: l10n.createOutletTerritoryNotChosen,
              error: _errors['territory'],
              // Better than an empty sheet that looks broken: the store
              // genuinely cannot be filed until a territory exists, and this
              // says who can fix it.
              emptyHeadline: l10n.createOutletNoTerritories,
              onChanged: (code) => setState(() {
                _territoryCode = code;
                _errors.remove('territory');
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the location lookup last said.
enum _LocationOutcome { found, denied, failed }

/// Where the store will be pinned, in one sentence and one action.
///
/// No figure: the coordinates are in the two fields directly beneath, and
/// printing them twice invites a manager to correct the copy that is not the
/// one being sent.
class _LocationLine extends StatelessWidget {
  const _LocationLine({
    required this.locating,
    required this.outcome,
    required this.onRetry,
  });

  final bool locating;
  final _LocationOutcome? outcome;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;

    final String sentence = locating
        ? l10n.createOutletLocating
        : switch (outcome) {
            _LocationOutcome.found => l10n.createOutletLocationFound,
            _LocationOutcome.denied => l10n.createOutletLocationDenied,
            _LocationOutcome.failed => l10n.createOutletLocationFailed,
            null => l10n.createOutletLocating,
          };

    return Column(
      key: const ValueKey<String>('create-outlet-location'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(sentence, style: skin.text.meta.style(color: skin.palette.ink3)),
        if (!locating) ...<Widget>[
          const SizedBox(height: TiqSpace.s2),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TorchTertiaryButton(
              key: const ValueKey<String>('create-outlet-relocate'),
              label: l10n.createOutletUseThisPhone,
              onPressed: onRetry,
            ),
          ),
        ],
      ],
    );
  }
}
