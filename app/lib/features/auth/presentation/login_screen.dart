import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/auth/session_ended.dart';
import '../../../core/design/torch_scope.dart';
import '../../../core/network/human_error.dart';
import '../../../core/theme/torchlight/entry_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import 'entry_frame.dart';
import 'entry_plate.dart';

/// Maps a login failure to a user-facing message. A 401 here means bad
/// credentials — the one place in the app where it does. Everywhere else a 401
/// is an expired session (the api_client interceptor signs the user out), so
/// the shared [humanErrorMessage] says "session expired"; saying that on the
/// login screen would tell the user the wrong story. Everything that is not a
/// 401 — connectivity, timeouts, rate limits, server errors — is delegated so
/// login and the rest of the app speak with the same voice.
///
/// **It never says whether the account exists.** One sentence covers a wrong
/// password, an unknown address, a disabled user and a typo, because anything
/// that distinguishes them turns this form into a way to ask the server who
/// works here.
///
/// Pass the active [l10n] (`context.l10n`); without it the English copy is
/// used.
String loginErrorMessage(Object error, [AppLocalizations? l10n]) {
  final l = l10n ?? englishLocalizations;
  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status == 401) return l.loginInvalidCredentials;
    // THE LOCKOUT, IN ITS OWN WORDS (30 September 2026). The shared 429 copy
    // — "Too many attempts. Wait a few minutes, then try again." — is written
    // for a screen where the person was doing something and got told to slow
    // down. Here they are trying to get *in*, and the question the pause
    // raises is not "how long" but "is my account gone". So this sentence
    // explains the rule and then answers that question, which the shared one
    // has no reason to.
    if (status == 429) return l.loginTooManyBody;
  }
  return humanErrorMessage(error, l);
}

/// The headline a sign-in failure is announced under.
///
/// A 401 and a 429 are **not the same story** and did not used to be told
/// apart: both printed "We could not sign you in", so the screen said the
/// person's credentials had been refused when in fact nothing had been
/// checked at all. The rate limit is a rule they tripped, not a judgement on
/// who they are, and the headline is where that difference is either made or
/// lost.
String loginErrorHeadline(Object error, [AppLocalizations? l10n]) {
  final l = l10n ?? englishLocalizations;
  if (error is DioException && error.response?.statusCode == 429) {
    return l.loginTooManyTitle;
  }
  return l.loginFailedTitle;
}

/// Which kind of failure a sign-in error is, in the kit's closed set.
///
/// A 401 is [TorchErrorKind.rejected] and offers no Retry: pressing a button
/// that sends the same wrong password again fails identically, and the field
/// the user has to change is already on the screen.
TorchErrorKind loginErrorKind(Object error) {
  if (error is! DioException) return TorchErrorKind.unknown;
  final status = error.response?.statusCode;
  if (status == 401) return TorchErrorKind.rejected;
  if (status == 429) return TorchErrorKind.rejected;
  if (status != null && status >= 500) return TorchErrorKind.server;
  return switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => TorchErrorKind.network,
    _ => TorchErrorKind.unknown,
  };
}

/// `/login` — the way in.
///
/// ## Amber, counted
///
/// Not a tab root and no nav, so Night has two content grants and Day
/// has one. **One object takes one of them: the sign-in button**, and only
/// while it is armed. An empty form carries zero amber in every skin — the
/// first screen anyone sees is also the screen with the least reason to be
/// lit, because nothing on it is ready to commit yet.
///
/// The trough's focus rule is ink, not amber (§15.5), so a focused field costs
/// nothing; the brand is a wordmark, and a word is never amber.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const EntryTorchlightRoute(child: _SignIn());
}

class _SignIn extends ConsumerStatefulWidget {
  const _SignIn();

  @override
  ConsumerState<_SignIn> createState() => _SignInState();
}

class _SignInState extends ConsumerState<_SignIn> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _show = false;

  // Deliberately local state, not `session.isLoading` — AsyncNotifier's state
  // is AsyncLoading from initial mount until build() resolves, which would
  // incorrectly disable the button (and show it busy) before any submission
  // has happened.
  bool _sending = false;

  /// Defaults to on, matching what the app has always done: the session was
  /// persisted unconditionally, checkbox or not. Honouring the box while
  /// leaving it unticked by default would silently switch every field agent to
  /// re-logging in each morning — a regression dressed up as a fix.
  bool _remember = true;

  /// The session-ended sheet is raised once, from the first frame that has a
  /// navigator under it, and never again on a rebuild.
  bool _askedAboutHeldWork = false;

  @override
  void initState() {
    super.initState();
    for (final c in <TextEditingController>[_email, _password]) {
      c.addListener(_changed);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerHeldWork());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[_email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  /// What is still missing, in the order the fields are on screen. Null when
  /// the primary can be pressed — and the same two sentences the form used to
  /// print under the fields, now under the button that will not move.
  String? _missing(AppLocalizations l10n) {
    if (_email.text.trim().isEmpty) return l10n.loginEmailRequired;
    if (_password.text.isEmpty) return l10n.loginPasswordRequired;
    return null;
  }

  /// Whether the reader has pressed Sign in yet.
  ///
  /// Nothing tells them what is missing until they have. The screen used to
  /// print "Email is required" on arrival, under a dead grey button, on a form
  /// nobody had touched — a scolding for a mistake not yet made.
  bool _tried = false;

  Future<void> _submit() async {
    // VALIDATE ON PRESS, NOT ON SIGHT — 30 September 2026.
    //
    // The button is live from the first frame. Press it empty and it says what
    // is missing; that is an action, which is what earns it the amber. A
    // disabled button wearing the screen's one light would be the lie the
    // amber law exists to prevent, and a dead button that has already told you
    // off is worse than either.
    final missing = _missing(context.l10n);
    if (missing != null) {
      setState(() => _tried = true);
      return;
    }
    setState(() => _sending = true);
    await ref
        .read(sessionControllerProvider.notifier)
        .login(
          // Trimmed and lowercased before it leaves the device (#351). An
          // Android keyboard capitalises the first letter of the email field by
          // default, and the backend's lookup is exact — so "Agent@…" came back
          // as "Invalid credentials" on a perfectly correct password. The
          // backend normalises too; this keeps the request itself honest.
          //
          // The password is passed through UNTOUCHED: leading or trailing
          // spaces in a password may be deliberate, and trimming one would
          // silently lock out whoever chose it.
          _email.text.trim().toLowerCase(),
          _password.text,
          rememberMe: _remember,
        );
    if (mounted) {
      setState(() => _sending = false);
    }
  }

  /// The field reset (#400): the agent redeems a code their manager read out.
  /// Whatever is already in the email field goes with them, so it is not
  /// typed twice.
  void _forgotPassword() {
    context.go('/forgot-password', extra: _email.text.trim());
  }

  /// SIGNED OUT WITH WORK ON THE PHONE (#380/#392).
  ///
  /// A state, not an error. The sheet names what is held before it names the
  /// session, is non-dismissible on its first appearance, and after "Not now"
  /// leaves the held line under this screen's header until somebody signs in
  /// and the outbox drains.
  Future<void> _offerHeldWork() async {
    if (_askedAboutHeldWork || !mounted) return;
    final ended = ref.read(sessionEndedProvider);
    if (ended == null || ended.answered || ended.isEmpty) return;
    _askedAboutHeldWork = true;
    final l10n = context.l10n;
    await showTorchSheet<bool>(
      context,
      dismissible: false,
      builder: (sheetContext) => SessionEndedSheet(
        key: const ValueKey<String>('session-ended-sheet'),
        title: l10n.sessionEndedTitle,
        body: l10n.sessionEndedBody,
        proofLabel: l10n.sessionHeldWhatIsHeld,
        signInLabel: l10n.sessionEndedSignIn,
        notNowLabel: l10n.sessionEndedNotNow,
        proof: <ProofLine>[
          for (final line in ended.lines)
            ProofLine(text: sessionHeldLineText(l10n, line)),
        ],
      ),
    );
    if (!mounted) return;
    ref.read(sessionEndedProvider.notifier).answered();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final session = ref.watch(sessionControllerProvider);
    final held = ref.watch(sessionEndedProvider);
    final missing = _missing(l10n);
    // Armed whenever it can be pressed at all — which is always, unless a
    // press is already in flight. See [_submit].
    final armed = !_sending;
    final failure = session.hasError ? session.error! : null;

    return TorchSheetAware(
      builder: (context, beneathSheet) => TorchScope(
        skin: skin,
        phase: _sending
            ? 'sending'
            : failure != null
            ? 'error'
            : armed
            ? 'armed'
            : 'blocked',
        navRenders: false,
        tabbedRoute: false,
        beneathSheet: beneathSheet,
        claims: <TorchClaim>[
          if (armed) TorchPrimaryButton.claim('sign-in'),
          // The underline asks at rung 5. On Night it is granted beside the
          // commit and the door matches the mockup; on Day the commit takes
          // the only grant and this falls back to `edgeControl`. Declared only
          // while the form is armed, because a screen with nothing to do
          // carries no light at all.
          if (armed)
            const TorchClaim(
              TorchClaimKind.textFieldFocus,
              id: 'forgot-password',
            ),
        ],
        child: EntryFrame(
          // NO APP HEADER, AND THE TWO REASONS ARE SEPARATE.
          //
          // **The title said what the headline now says.** A `TorchAppHeader`
          // prints its title at `title.l` — the same 20sp "Tasks" and "Ask
          // TradeIQ" carry — and then this screen printed "Sign in" again on
          // the button in the thumb zone. Ask's opening is the shape this
          // screen wants and it has exactly one of each: a mark that says
          // which product, and a display headline that says what to do. Two
          // chrome-scale statements of "Sign in" above a form is the
          // duplication §1.6 and §9f keep deleting, one component up.
          //
          // **The back arrow went nowhere.** It ran `go('/')`, and `/` is the
          // splash, which holds for five seconds and then routes an
          // unauthenticated visitor straight back to `/login`. It was a
          // five-second round trip to the screen you were already on, and it
          // cost the 48dp row the header reserves above its title on the one
          // screen in the product with the least room to spare — see the
          // 360x640 renders, where "Remember me" was being clipped by the
          // thumb zone. Nothing is unreachable without it: the splash is a
          // brand hold and not a destination, and `/forgot-password` is
          // reached from the link that is still on this screen.
          //
          // No skin cycle anywhere on this frame any more — the owner struck
          // the control on 1 October 2026 and `entry_frame.dart` records what
          // that cost. The commit row is the button alone, edge to edge, as
          // the mockup has it.
          // UNDER THE COMMIT, CENTRED — owner instruction, 30 September 2026,
          // pointing at the approved mockup: "look at the Sign in and forgot
          // password on this image and do exactly that".
          //
          // It used to sit left-aligned inside the form, under the checkboxes,
          // where it read as one more form control. A person reaches for the
          // button first; the way out is what they look for once the button
          // has not worked for them, and that is now the order it reads in.
          underPrimary: TorchTertiaryButton(
            // The mockup's amber underline — asked for, not taken. See
            // `TorchTertiaryButton.litClaimId`.
            litClaimId: 'forgot-password',
            key: const ValueKey<String>('login-forgot-password'),
            label: l10n.loginForgotPassword,
            onPressed: _forgotPassword,
          ),
          primary: TorchPrimaryButton(
            key: const ValueKey<String>('login-submit'),
            label: l10n.loginSignIn,
            claimId: 'sign-in',
            busy: _sending,
            blockedReason: _tried ? missing : null,
            onPressed: armed ? _submit : null,
          ),
          children: <Widget>[
            // THE MASTHEAD IS A PHOTOGRAPHIC PLATE (owner's choice, 30
            // September 2026 — *"A the plate"*).
            //
            // It used to be a mark, a headline and a sentence on bare ground.
            // It is now the same three things on the object The Floor opens
            // with: the plate is the one piece of this product nobody else
            // has, and on the door it means the product looks like itself
            // before anyone has typed a character.
            //
            // **The three strings did not change.** `loginHeadline` and
            // `loginSubtitle` are the same two sentences, moved onto the
            // picture; the mark is the same 24dp compact wordmark, at the top
            // of the plate instead of above it. Nothing here names a
            // territory, a route or a count, because before sign-in there is
            // no tenant and nothing of the sort is true yet — see the long
            // note in `entry_plate.dart`, which is also where the amber and
            // the fold arithmetic are argued.
            //
            // At 360×640 it collapses to the 96dp band by its own budget and
            // the picture is dropped, which is very nearly the masthead this
            // screen already had.
            EntryPlate(
              headline: l10n.loginHeadline,
              supporting: l10n.loginSubtitle,
            ),
            SizedBox(height: skin.space.blockGap),
            if (held != null && !held.isEmpty) ...<Widget>[
              SessionHeldLine(
                key: const ValueKey<String>('login-held-line'),
                message: l10n.sessionHeldWaiting(held.total),
                actionLabel: l10n.sessionHeldWhatIsHeld,
                onPressed: () => _showHeldWork(l10n, held),
              ),
              SizedBox(height: skin.space.blockGap),
            ],
            // ABOVE the fields, not under the button. A refusal here is about
            // the two things directly beneath it, and on a 360×640 phone the
            // foot of this form is already past the fold: an error printed
            // there is an error the person has to go looking for, on the one
            // screen where they do not yet know what went wrong.
            if (failure != null) ...<Widget>[
              ErrorState(
                key: const ValueKey<String>('login-error'),
                scope: ErrorScope.inline,
                message: TorchErrorMessage(
                  kind: loginErrorKind(failure),
                  headline: loginErrorHeadline(failure, l10n),
                  body: loginErrorMessage(failure, l10n),
                  offersRetry: false,
                ),
              ),
              SizedBox(height: skin.space.blockGap),
            ],
            TorchTextField(
              key: const ValueKey<String>('login-email'),
              label: l10n.loginEmailLabel,
              hint: l10n.loginEmailHint,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              // An email address has no capital letters to offer and nothing
              // to correct. Android capitalises the first letter of a text
              // field by default and would happily "fix" a domain into a
              // dictionary word, which is how a correct password started
              // failing to log in (#351).
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              autofillHints: const <String>[
                AutofillHints.username,
                AutofillHints.email,
              ],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: TiqSpace.s5),
            TorchTextField(
              key: const ValueKey<String>('login-password'),
              label: l10n.loginPasswordLabel,
              hint: l10n.loginPasswordHint,
              controller: _password,
              obscureText: !_show,
              autofillHints: const <String>[AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                _submit();
              },
            ),
            SizedBox(height: skin.space.intraBlock),
            TorchCheckbox(
              key: const ValueKey<String>('login-show-password'),
              label: l10n.loginShowPassword,
              value: _show,
              onChanged: (v) => setState(() => _show = v),
            ),
            TorchCheckbox(
              key: const ValueKey<String>('login-remember-me'),
              label: l10n.loginRememberMe,
              value: _remember,
              onChanged: (v) => setState(() => _remember = v),
            ),
          ],
        ),
      ),
    );
  }

  /// "What is held" from the line under the header: the same proof block,
  /// dismissible this time, because by now the person has already answered.
  void _showHeldWork(AppLocalizations l10n, SessionEnded held) {
    showTorchSheet<void>(
      context,
      builder: (sheetContext) => TorchSheet(
        title: l10n.sessionHeldWhatIsHeld,
        subtitle: l10n.sessionEndedBody,
        child: ProofBlock(
          lines: <ProofLine>[
            for (final line in held.lines)
              ProofLine(text: sessionHeldLineText(l10n, line)),
          ],
          semanticsLabel: l10n.sessionHeldWhatIsHeld,
        ),
      ),
    );
  }
}
