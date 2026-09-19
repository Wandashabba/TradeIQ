import 'package:flutter/material.dart' show MaterialLocalizations, TimeOfDay;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/password_repository.dart';
import '../../../core/auth/password_rule.dart';
import '../../../core/network/human_error.dart';
import '../../../core/theme/torchlight/agent_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../../auth/presentation/account_frame.dart';
import '../data/users_repository.dart';

/// Whether a staff [actorRole] may set or reset the password of a
/// [targetRole] — the server's `staffMaySetPasswordFor`, mirrored so the
/// console only offers what the server will do. The server still decides.
///
/// A manager may reset field agents and nobody else: a manager who could reset
/// an admin could take the tenant. An admin may reset anyone in the tenant.
bool staffMaySetPasswordFor(String? actorRole, String targetRole) =>
    actorRole == 'admin' ||
    (actorRole == 'manager' && targetRole == 'field_agent');

/// `/users/:id/password` — a manager or admin resets someone's password
/// (#400). English, like the rest of the console.
///
/// Two ways, because the two situations differ:
///
/// - **In the field** — generate a one-time code and read it out. The person
///   then chooses their own password at "Forgot password?" on their phone,
///   and the manager never learns it. This is the primary.
/// - **In person** — type a password for them now. The manager knows it, so it
///   is the second choice and says so.
///
/// ## The code on screen
///
/// The code is returned once, to the person who generated it, and exists on
/// this phone only in this screen's state. It is never persisted, never
/// logged, never put in a provider another screen could read, and it is gone
/// when the screen closes. "Done" is the primary once it is showing.
class UserPasswordScreen extends StatelessWidget {
  const UserPasswordScreen({super.key, required this.userId, this.user});

  final String userId;

  /// Handed over by the users list. Null on a cold start or a refresh at this
  /// URL, in which case it is looked up in the same list.
  final AppUser? user;

  @override
  Widget build(BuildContext context) => TorchlightRoute(
    child: _UserPassword(userId: userId, initial: user),
  );
}

class _UserPassword extends ConsumerStatefulWidget {
  const _UserPassword({required this.userId, this.initial});

  final String userId;
  final AppUser? initial;

  @override
  ConsumerState<_UserPassword> createState() => _UserPasswordState();
}

class _UserPasswordState extends ConsumerState<_UserPassword> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  IssuedResetCode? _code;
  bool _issuing = false;
  bool _setting = false;
  bool _setDone = false;
  bool _show = false;

  PasswordProblem? _passwordProblem;
  bool _mismatch = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    for (final c in [_password, _confirm]) {
      c.addListener(_changed);
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(() {
      _passwordProblem = null;
      _mismatch = false;
      if (_password.text.isNotEmpty) _setDone = false;
    });
  }

  @override
  void dispose() {
    for (final c in [_password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _leave() => context.go('/users');

  String _refusalText(PasswordRefusal reason) => switch (reason) {
    PasswordRefusal.notPermitted =>
      'You can reset field agents only. Ask an admin to reset this account.',
    PasswordRefusal.notFound => 'That user is not in your organisation.',
    PasswordRefusal.passwordRejected => PasswordProblem.rejected.message(
      englishLocalizations,
    ),
    // Neither can come back from a staff route; worded as the generic
    // failure rather than guessed at.
    PasswordRefusal.wrongCurrentPassword ||
    PasswordRefusal.codeRejected => englishLocalizations.errorGeneric,
  };

  Future<void> _issue() async {
    setState(() {
      _issuing = true;
      _failure = null;
      _code = null;
    });
    try {
      final issued = await ref
          .read(passwordRepositoryProvider)
          .issueResetCode(widget.userId);
      if (!mounted) return;
      setState(() {
        _issuing = false;
        _code = issued;
      });
    } on PasswordRefused catch (e) {
      if (!mounted) return;
      setState(() {
        _issuing = false;
        _failure = _refusalText(e.reason);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _issuing = false;
        _failure = humanErrorMessage(e);
      });
    }
  }

  String? _setMissing() {
    if (_password.text.isEmpty) return 'Type a password for them first';
    if (_confirm.text.isEmpty) return 'Type the password again';
    return null;
  }

  Future<void> _set(String? email) async {
    final problem = checkNewPassword(_password.text, email: email);
    final mismatch = _password.text != _confirm.text;
    if (problem != null || mismatch) {
      setState(() {
        _passwordProblem = problem;
        _mismatch = problem == null && mismatch;
      });
      return;
    }
    setState(() {
      _setting = true;
      _failure = null;
    });
    try {
      await ref
          .read(passwordRepositoryProvider)
          .setPasswordFor(widget.userId, _password.text);
      if (!mounted) return;
      setState(() {
        _setting = false;
        _password.clear();
        _confirm.clear();
        _setDone = true;
      });
    } on PasswordRefused catch (e) {
      if (!mounted) return;
      setState(() {
        _setting = false;
        if (e.reason == PasswordRefusal.passwordRejected) {
          _passwordProblem = PasswordProblem.rejected;
        } else {
          _failure = _refusalText(e.reason);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _setting = false;
        _failure = humanErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final user =
        widget.initial ??
        ref
            .watch(usersListProvider)
            .value
            ?.where((u) => u.id == widget.userId)
            .firstOrNull;
    final who = user?.label ?? 'this user';
    final code = _code;
    final setMissing = _setMissing();
    final failure = _failure;

    final primary = code == null
        ? TorchPrimaryButton(
            key: const ValueKey<String>('issue-reset-code'),
            label: 'Generate reset code',
            claimId: AccountFrame.primaryClaimId,
            busy: _issuing,
            onPressed: _issuing ? null : _issue,
          )
        : TorchPrimaryButton(
            key: const ValueKey<String>('reset-code-done'),
            label: 'Done',
            claimId: AccountFrame.primaryClaimId,
            onPressed: _leave,
          );

    return AccountFrame(
      phase: _issuing
          ? 'issuing'
          : code != null
          ? 'code-shown'
          : failure != null
          ? 'error'
          : 'ready',
      title: 'Reset password',
      back: AccountFrame.backTo('Back to users', _leave),
      primaryArmed: !_issuing,
      primary: primary,
      children: <Widget>[
        AccountHeadline(who),
        if (user != null && user.label != user.email) ...<Widget>[
          const SizedBox(height: TiqSpace.s1),
          AccountText(user.email, muted: true),
        ],
        const SizedBox(height: TiqSpace.s6),
        const SectionRule('In the field'),
        const SizedBox(height: TiqSpace.s3),
        const AccountText(
          'Generate a one-time code and read it out. They type it at '
          '"Forgot password?" on their phone and choose their own password. '
          'It works once, for 15 minutes, and a new code cancels the old one.',
        ),
        if (code != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s5),
          _CodeBlock(code: code),
          const SizedBox(height: TiqSpace.s2),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TorchTertiaryButton(
              key: const ValueKey<String>('reissue-reset-code'),
              label: 'Make a new code instead',
              semanticLabel: 'Make a new code. This one stops working.',
              onPressed: _issue,
            ),
          ),
        ],
        const SizedBox(height: TiqSpace.s7),
        const SectionRule('In person'),
        const SizedBox(height: TiqSpace.s3),
        const AccountText(
          'Or set a password for them now. You will know it, so tell them in '
          'person and never send it by message.',
        ),
        const SizedBox(height: TiqSpace.s5),
        TorchTextField(
          key: const ValueKey<String>('set-password-field'),
          label: 'New password',
          controller: _password,
          obscureText: !_show,
          help: englishLocalizations.passwordRuleHelp,
          error: _passwordProblem?.message(englishLocalizations),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: TiqSpace.s5),
        TorchTextField(
          key: const ValueKey<String>('set-password-confirm'),
          label: 'New password again',
          controller: _confirm,
          obscureText: !_show,
          error: _mismatch ? englishLocalizations.passwordMismatch : null,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: TiqSpace.s3),
        TorchCheckbox(
          key: const ValueKey<String>('set-password-show'),
          label: 'Show password',
          value: _show,
          onChanged: (v) => setState(() => _show = v),
        ),
        const SizedBox(height: TiqSpace.s3),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TorchSecondaryButton(
            key: const ValueKey<String>('set-password'),
            label: 'Set password',
            busy: _setting,
            blockedReason: setMissing,
            onPressed: setMissing == null && !_setting
                ? () => _set(user?.email)
                : null,
          ),
        ),
        if (_setDone) ...<Widget>[
          const SizedBox(height: TiqSpace.s3),
          AccountText(
            key: const ValueKey<String>('set-password-done'),
            'Password set for $who. Sessions already signed in to this account '
            'stay signed in until they expire, up to 12 hours. To cut a lost '
            'phone off now, switch the account off on the users list.',
          ),
        ],
        if (failure != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s5),
          ErrorState(
            key: const ValueKey<String>('user-password-failure'),
            scope: ErrorScope.inline,
            message: TorchErrorMessage(
              kind: TorchErrorKind.rejected,
              headline: 'Nothing was changed',
              body: failure,
              offersRetry: false,
            ),
          ),
        ],
        // Keeps the code block clear of the thumb zone when it is the last
        // thing on a short phone.
        SizedBox(height: skin.space.gutter),
      ],
    );
  }
}

/// The code, as the manager reads it out: two groups of four in the mono
/// face, and read to a screen reader one digit at a time — "4 8 2 1 7 3 9 0",
/// never "forty-eight million".
class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code});

  final IssuedResetCode code;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final digits = code.code;
    final grouped = digits.length == 8
        ? '${digits.substring(0, 4)} ${digits.substring(4)}'
        : digits;
    final expires = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(code.expiresAt));
    return Column(
      key: const ValueKey<String>('reset-code-block'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // The figure face at figure size, because it is read aloud across a
        // counter. Not through FigureSlot: this is a code, not a quantity, and
        // a formatter that groups thousands would corrupt it.
        Semantics(
          label: 'Reset code ${digits.split('').join(' ')}',
          excludeSemantics: true,
          child: Text(
            grouped,
            key: const ValueKey<String>('reset-code'),
            style: skin.text.figureL.style(color: skin.palette.ink1),
          ),
        ),
        const SizedBox(height: TiqSpace.s2),
        AccountText('For ${code.email}. Works once, until $expires.'),
        const SizedBox(height: TiqSpace.s1),
        const AccountText(
          'This is the only time the code is shown. Close this screen once '
          'you have read it out.',
          muted: true,
        ),
      ],
    );
  }
}
