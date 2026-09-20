import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/password_repository.dart';
import '../../../core/auth/password_rule.dart';
import '../../../core/network/human_error.dart';
import '../../../core/theme/torchlight/agent_skin.dart';
import '../../../core/widgets/torchlight/skin_controls.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import 'account_frame.dart';

/// `/account/password` — the signed-in user changes their own password (#400).
///
/// The current password is asked for again because the phone is shared and may
/// be lying unlocked: a token in hand is not proof of who is holding it.
///
/// A wrong current password does **not** sign anyone out. The API client signs
/// out on a 401 everywhere else, because there a 401 means the 12h token
/// expired; the server tags this one `current_password_incorrect` and the
/// client lets it through as an ordinary field error.
class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const TorchlightRoute(child: _ChangePassword());
}

class _ChangePassword extends ConsumerStatefulWidget {
  const _ChangePassword();

  @override
  ConsumerState<_ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends ConsumerState<_ChangePassword> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _show = false;
  bool _sending = false;
  bool _done = false;

  bool _wrongCurrent = false;
  PasswordProblem? _passwordProblem;
  bool _mismatch = false;

  /// The request failed for a reason that is not about a field.
  String? _failure;

  @override
  void initState() {
    super.initState();
    for (final c in [_current, _password, _confirm]) {
      c.addListener(_changed);
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(() {
      _wrongCurrent = false;
      _passwordProblem = null;
      _mismatch = false;
    });
  }

  @override
  void dispose() {
    for (final c in [_current, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _missing(AppLocalizations l10n) {
    if (_current.text.isEmpty) return l10n.changeNeedsCurrent;
    if (_password.text.isEmpty) return l10n.passwordNeedsNew;
    if (_confirm.text.isEmpty) return l10n.passwordNeedsConfirm;
    return null;
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/notifications');
    }
  }

  Future<void> _submit() async {
    final problem = checkNewPassword(_password.text);
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
          .changePassword(
            currentPassword: _current.text,
            newPassword: _password.text,
          );
      if (!mounted) return;
      setState(() {
        _sending = false;
        _done = true;
        _current.clear();
        _password.clear();
        _confirm.clear();
      });
    } on PasswordRefused catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        switch (e.reason) {
          case PasswordRefusal.wrongCurrentPassword:
            _wrongCurrent = true;
          case PasswordRefusal.passwordRejected:
            _passwordProblem = PasswordProblem.rejected;
          case PasswordRefusal.codeRejected:
          case PasswordRefusal.notPermitted:
          case PasswordRefusal.notFound:
            _failure = l10n.errorGeneric;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _failure = humanErrorMessage(e, l10n);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final back = AccountFrame.backTo(l10n.changePasswordBack, _leave);

    if (_done) {
      return AccountFrame(
        phase: 'done',
        title: l10n.changePasswordTitle,
        back: back,
        primaryArmed: true,
        skinCycle: const AgentSkinCycle(),
        primary: TorchPrimaryButton(
          key: const ValueKey<String>('change-done'),
          label: l10n.changeDone,
          claimId: AccountFrame.primaryClaimId,
          onPressed: _leave,
        ),
        children: <Widget>[
          AccountHeadline(l10n.changeDoneTitle),
          const SizedBox(height: TiqSpace.s3),
          AccountText(l10n.changeDoneBody),
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
      title: l10n.changePasswordTitle,
      back: back,
      primaryArmed: armed,
      skinCycle: const AgentSkinCycle(),
      primary: TorchPrimaryButton(
        key: const ValueKey<String>('change-submit'),
        label: l10n.changePasswordTitle,
        claimId: AccountFrame.primaryClaimId,
        busy: _sending,
        blockedReason: missing,
        onPressed: armed ? _submit : null,
      ),
      children: <Widget>[
        TorchTextField(
          key: const ValueKey<String>('change-current-password'),
          label: l10n.changeCurrentLabel,
          controller: _current,
          obscureText: !_show,
          autofillHints: const <String>[AutofillHints.password],
          error: _wrongCurrent ? l10n.changeWrongCurrent : null,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: TiqSpace.s5),
        TorchTextField(
          key: const ValueKey<String>('change-new-password'),
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
          key: const ValueKey<String>('change-confirm-password'),
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
          key: const ValueKey<String>('change-show-passwords'),
          label: l10n.passwordShow,
          value: _show,
          onChanged: (v) => setState(() => _show = v),
        ),
        if (failure != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s5),
          ErrorState(
            key: const ValueKey<String>('change-failure'),
            scope: ErrorScope.inline,
            message: TorchErrorMessage(
              kind: TorchErrorKind.rejected,
              headline: l10n.passwordFailedTitle,
              body: failure,
              offersRetry: false,
            ),
          ),
        ],
      ],
    );
  }
}
