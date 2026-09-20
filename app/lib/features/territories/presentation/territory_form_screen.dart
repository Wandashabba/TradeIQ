import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart' show TextCapitalization;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../data/territories_repository.dart';

/// NEW TERRITORY — a name, a code and, if anyone knows it, a region.
///
/// ## The frame
///
/// A pushed console route, so there is no nav and the bottom region is a
/// [TorchThumbZone] holding the one commit. The shell asserts on a nav and a
/// thumb-zone primary together, and it is right to: 64dp of nav plus 96dp of
/// thumb zone plus a safe area is a quarter of a 640dp screen given to chrome.
///
/// ## The amber, counted
///
/// Untabbed, no nav, so Night has two content grants and this route spends
/// **one**: `Create territory` at rung 1. Day and Veld spend their single
/// grant on the same block. The focused field's rule is ink-1 and 2px here,
/// not flame-700 — Phase 2 ships no light in the input folder and the
/// accessibility requirement the ruling states (2px minimum, never
/// colour-only) is met by the thickening.
///
/// ## Validation says what is wrong, where it is wrong
///
/// `Form`/`TextFormField` is gone with the rest of Material, so the two
/// required fields carry their own `error` strings and the primary carries a
/// `blockedReason` above itself as a live region. Nothing is disabled without
/// a sentence naming what is missing: a greyed button with no reason is a
/// screen refusing to say why.
class TerritoryFormScreen extends ConsumerStatefulWidget {
  const TerritoryFormScreen({super.key});

  @override
  ConsumerState<TerritoryFormScreen> createState() =>
      _TerritoryFormScreenState();
}

class _TerritoryFormScreenState extends ConsumerState<TerritoryFormScreen> {
  static const String createClaimId = 'create-territory';

  final TextEditingController _name = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _region = TextEditingController();

  bool _submitting = false;
  bool _submitted = false;
  TorchErrorMessage? _failure;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _region.dispose();
    super.dispose();
  }

  String get _nameValue => _name.text.trim();
  String get _codeValue => _code.text.trim();

  bool get _ready => _nameValue.isNotEmpty && _codeValue.isNotEmpty;

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (!_ready || _submitting) return;
    setState(() {
      _submitting = true;
      _failure = null;
    });
    final l10n = context.l10n;
    final region = _region.text.trim();
    try {
      await ref
          .read(territoriesRepositoryProvider)
          .createTerritory(
            name: _nameValue,
            code: _codeValue,
            region: region.isEmpty ? null : region,
          );
      ref.invalidate(territoriesListProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      showTorchToast(
        context,
        message: l10n.territoryCreated(_nameValue),
        kind: ToastKind.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        // Sanitised, never the exception's own toString: a message that is
        // sometimes an exception is a message that one day carries a host name
        // into a screenshot in a WhatsApp group.
        _failure = TorchErrorMessage.sanitise(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final nameError = _submitted && _nameValue.isEmpty
        ? l10n.territoryFieldRequired
        : null;
    final codeError = _submitted && _codeValue.isEmpty
        ? l10n.territoryFieldRequired
        : null;

    return TorchSheetAware(
      builder: (context, beneathSheet) => TorchScope(
        skin: skin,
        phase: _submitting ? 'submitting' : 'form',
        navRenders: false,
        tabbedRoute: false,
        beneathSheet: beneathSheet,
        claims: const <TorchClaim>[TorchClaim.primaryCommit(createClaimId)],
        child: TorchShell(
          profile: TorchShellProfile.console,
          header: TorchAppHeader(
            title: l10n.territoryNewTitle,
            facts: <String>[l10n.territoryNewFact],
            back: TorchIconButton(
              key: const ValueKey<String>('back-to-territories'),
              icon: Icons.arrow_back,
              // The destination, never "Back".
              semanticLabel: l10n.territoryBackToList,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          primary: TorchPrimaryButton(
            key: const ValueKey<String>('territory-save-button'),
            claimId: createClaimId,
            label: l10n.territoryCreate,
            busy: _submitting,
            blockedReason: _ready ? null : l10n.territoryCreateBlocked,
            onPressed: _ready ? _submit : null,
          ),
          children: <Widget>[
            TorchTextField(
              key: const ValueKey<String>('territory-name-field'),
              label: l10n.territoryNameLabel,
              help: l10n.territoryNameHelp,
              controller: _name,
              error: nameError,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: skin.space.intraBlock),
            TorchTextField(
              key: const ValueKey<String>('territory-code-field'),
              label: l10n.territoryCodeLabel,
              help: l10n.territoryCodeHelp,
              controller: _code,
              error: codeError,
              // A code is a machine identifier, so it wears the identifier
              // face and stops autocorrect rewriting `GP-N` into a word.
              identifier: true,
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: skin.space.intraBlock),
            TorchTextField(
              key: const ValueKey<String>('territory-region-field'),
              label: l10n.territoryRegionLabel,
              help: l10n.territoryRegionHelp,
              controller: _region,
              textCapitalization: TextCapitalization.words,
            ),
            if (_failure != null) ...<Widget>[
              SizedBox(height: skin.space.blockGap),
              TorchErrorRegion(
                name: 'create territory',
                child: ErrorState(
                  scope: ErrorScope.inline,
                  message: _failure!,
                  action: _failure!.offersRetry
                      ? TorchTertiaryButton(
                          key: const ValueKey<String>('territory-create-retry'),
                          label: l10n.torchTryAgain,
                          onPressed: _submit,
                        )
                      : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
