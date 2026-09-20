import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/password_repository.dart';
import '../../../core/auth/password_rule.dart';
import '../../../core/network/human_error.dart';
import '../../../core/theme/torchlight/entry_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import 'account_frame.dart';

/// `/forgot-password` — redeem a code a manager read out (#400).
///
/// There is no email reset: SMTP is not configured, and a link in an inbox is
/// no use to someone who cannot sign in to read it. The manager generates a
/// one-time code in TradeIQ and reads it out; the agent types it here with a
/// password of their own choosing, which the manager never learns.
///
/// Every refusal of the code reads the same, because the server answers every
/// cause the same — an unknown email, a wrong code, an old code and a used one
/// are one sentence, so this screen cannot be used to learn who has an account.
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  /// Whatever was in the sign-in screen's email field, so it is not typed
  /// twice.
  final String? initialEmail;

  @override
  Widget build(BuildContext context) =>
      EntryTorchlightRoute(child: _ForgotPassword(initialEmail: initialEmail));
}

class _ForgotPassword extends ConsumerStatefulWidget {
  const _ForgotPassword({this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<_ForgotPassword> createState() => _ForgotPasswordState();
}

/// Digits only, once the spaces and hyphens a code is read out with are gone.
String resetCodeDigits(String typed) => typed.replaceAll(RegExp(r'[\s-]'), '');

bool _isEightDigits(String typed) =>
    RegExp(r'^\d{8}$').hasMatch(resetCodeDigits(typed));

class _ForgotPasswordState extends ConsumerState<_ForgotPassword> {
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _show = false;
  bool _sending = false;
  bool _done = false;

  /// A failure that is not about one field: the code did not work, or the
  /// request never landed.
  ({String headline, String body})? _failure;
  PasswordProblem? _passwordProblem;
  bool _mismatch = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_email, _code, _password, _confirm]) {
      c.addListener(_changed);
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(() {
      // A correction clears the complaint about what was corrected.
      _passwordProblem = null;
      _mismatch = false;
    });
  }

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  /// What is still missing, in the order the fields are on screen. Null when
  /// the primary can be pressed.
  String? _missing(AppLocalizations l10n) {
    if (_email.text.trim().isEmpty) return l10n.forgotNeedsEmail;
    if (!_isEightDigits(_code.text)) return l10n.forgotNeedsCode;
    if (_password.text.isEmpty) return l10n.passwordNeedsNew;
    if (_confirm.text.isEmpty) return l10n.passwordNeedsConfirm;
    return null;
  }

  Future<void> _submit() async {
    final problem = checkNewPassword(_password.text, email: _email.text);
    final mismatch = _password.text != _confirm.text;
    if (problem != null || mismatch) {
      setState(() {
        _passwordProblem = problem;
        _mismatch = problem == null && mismatch;
        _failure = null;
      });
      return;
    }

    setState(() {
      _sending = true;
      _failure = null;
    });
    final l10n = context.l10n;
    try {
      await ref
          .read(passwordRepositoryProvider)
          .redeemResetCode(
            email: _email.text,
            code: _code.text,
            newPassword: _password.text,
          );
      if (!mounted) return;
      setState(() {
        _sending = false;
        _done = true;
        // Nothing secret outlives the success on this screen.
        _code.clear();
        _password.clear();
        _confirm.clear();
      });
    } on PasswordRefused catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        if (e.reason == PasswordRefusal.passwordRejected) {
          _passwordProblem = PasswordProblem.rejected;
        } else {
          _failure = (
            headline: l10n.forgotCodeRejectedTitle,
            body: l10n.forgotCodeRejectedBody,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _failure = (
          headline: l10n.passwordFailedTitle,
          body: humanErrorMessage(e, l10n),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final back = AccountFrame.backTo(
      l10n.forgotBack,
      () => context.go('/login'),
    );

    if (_done) {
      return AccountFrame(
        phase: 'done',
        title: l10n.forgotTitle,
        back: back,
        primaryArmed: true,
        skinCycle: const EntrySkinCycle(),
        primary: TorchPrimaryButton(
          key: const ValueKey<String>('forgot-go-to-sign-in'),
          label: l10n.forgotGoToSignIn,
          claimId: AccountFrame.primaryClaimId,
          onPressed: () => context.go('/login'),
        ),
        children: <Widget>[
          AccountHeadline(l10n.forgotDoneTitle),
          const SizedBox(height: TiqSpace.s3),
          AccountText(l10n.forgotDoneBody),
          const SizedBox(height: TiqSpace.s5),
          AccountText(l10n.passwordOtherSessions, muted: true),
        ],
      );
    }

    final missing = _missing(l10n);
    final armed = missing == null && !_sending;
    final failure = _failure;

    return AccountFrame(
      phase: _sending
          ? 'sending'
          : failure != null
          ? 'error'
          : armed
          ? 'armed'
          : 'blocked',
      title: l10n.forgotTitle,
      back: back,
      primaryArmed: armed,
      skinCycle: const EntrySkinCycle(),
      primary: TorchPrimaryButton(
        key: const ValueKey<String>('forgot-submit'),
        label: l10n.forgotSubmit,
        claimId: AccountFrame.primaryClaimId,
        busy: _sending,
        blockedReason: missing,
        onPressed: armed ? _submit : null,
      ),
      children: <Widget>[
        AccountText(l10n.forgotIntro),
        const SizedBox(height: TiqSpace.s6),
        TorchTextField(
          key: const ValueKey<String>('forgot-email'),
          label: l10n.forgotEmailLabel,
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          autofillHints: const <String>[AutofillHints.email],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: TiqSpace.s5),
        TorchTextField(
          key: const ValueKey<String>('forgot-code'),
          label: l10n.forgotCodeLabel,
          hint: l10n.forgotCodeHint,
          controller: _code,
          identifier: true,
          keyboardType: TextInputType.number,
          autofillHints: const <String>[AutofillHints.oneTimeCode],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: TiqSpace.s5),
        TorchTextField(
          key: const ValueKey<String>('forgot-new-password'),
          label: l10n.forgotNewPasswordLabel,
          controller: _password,
          obscureText: !_show,
          autofillHints: const <String>[AutofillHints.newPassword],
          help: l10n.passwordRuleHelp,
          error: _passwordProblem?.message(l10n),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: TiqSpace.s5),
        TorchTextField(
          key: const ValueKey<String>('forgot-confirm-password'),
          label: l10n.forgotConfirmLabel,
          controller: _confirm,
          obscureText: !_show,
          autofillHints: const <String>[AutofillHints.newPassword],
          error: _mismatch ? l10n.passwordMismatch : null,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (armed) _submit();
          },
        ),
        const SizedBox(height: TiqSpace.s3),
        TorchCheckbox(
          key: const ValueKey<String>('forgot-show-passwords'),
          label: l10n.passwordShow,
          value: _show,
          onChanged: (v) => setState(() => _show = v),
        ),
        if (failure != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s5),
          ErrorState(
            key: const ValueKey<String>('forgot-failure'),
            scope: ErrorScope.inline,
            message: TorchErrorMessage(
              kind: TorchErrorKind.rejected,
              headline: failure.headline,
              body: failure.body,
              offersRetry: false,
            ),
          ),
        ],
      ],
    );
  }
}
