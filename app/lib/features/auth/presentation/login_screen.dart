import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/network/human_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/agent_motion.dart';
import '../../../core/widgets/dimmed_aisle_backdrop.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/lumen_kit.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../../../core/widgets/trade_iq_logo.dart';
import '../../../core/theme/lumen_palette.dart';

/// Maps a login failure to a user-facing message. A 401 here means bad
/// credentials — the one place in the app where it does. Everywhere else a 401
/// is an expired session (the api_client interceptor signs the user out), so
/// the shared [humanErrorMessage] says "session expired"; saying that on the
/// login screen would tell the user the wrong story. Everything that is not a
/// 401 — connectivity, timeouts, server errors — is delegated so login and the
/// rest of the app speak with the same voice.
String loginErrorMessage(Object error) {
  if (error is DioException && error.response?.statusCode == 401) {
    return 'Invalid credentials';
  }
  return humanErrorMessage(error);
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Deliberately local state, not `session.isLoading` — AsyncNotifier's state
  // is AsyncLoading from initial mount until build() resolves, which would
  // incorrectly disable the button (and show a spinner) before any
  // submission has happened.
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  /// Defaults to on, matching what the app has always done: the session was
  /// persisted unconditionally, checkbox or not. Honouring the box while
  /// leaving it unticked by default would silently switch every field agent to
  /// re-logging in each morning — a regression dressed up as a fix.
  bool _rememberMe = true;

  /// The aisle behind the form, as a still: the first frame of the splash's
  /// footage, never played — a picture of a real store, not motion competing
  /// with the fields.
  final _footage = VideoPlayerController.asset(
    'assets/videos/Steadycam_gliding_down_aisle_202607102247.mp4',
  );

  @override
  void initState() {
    super.initState();
    _initializeFootage();
  }

  Future<void> _initializeFootage() async {
    try {
      await _footage.initialize();
      await _footage.setVolume(0);
      if (mounted) setState(() {});
    } on UnimplementedError {
      // Widget tests have no platform video player; the ground stands alone.
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _footage.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSubmitting = true);
    await ref
        .read(sessionControllerProvider.notifier)
        .login(
          _emailController.text,
          _passwordController.text,
          rememberMe: _rememberMe,
        );
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  void _showUnavailableMessage(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature is not available yet.')));
  }

  @override
  Widget build(BuildContext context) {
    // Light is Lumen Glass: the form is one pane on the lit ground. Dark keeps
    // the dimmed-aisle sign-in exactly as it was, pinned to the dark theme.
    if (context.colors.glass) return _glassLayout(context);
    return Theme(
      data: AppTheme.dark(),
      child: Builder(builder: _darkLayout),
    );
  }

  /// The fade-and-rise the form arrives with — instant under reduced motion.
  Widget _entrance(BuildContext context, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: reduceMotion(context) ? 0 : 400),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 12),
          child: child,
        ),
      ),
      child: child,
    );
  }

  Widget _glassLayout(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.plane,
      body: LitGround(
        backdrop: AisleFootage(controller: _footage),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 14, 8, 4),
                    child: Row(
                      children: [
                        GlassBackChip(
                          tooltip: 'Back to welcome',
                          onTap: () => context.go('/'),
                        ),
                        const Expanded(
                          child: Center(child: TradeIqLogo(size: 34)),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                      child: _entrance(
                        context,
                        GlassPane(
                          kind: GlassKind.panel,
                          radius: LumenGlass.radiusScore,
                          padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                          child: _form(context, glass: true),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _darkLayout(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Same dimmed footage as the splash, held on its first frame.
          DimmedAisleBackdrop(controller: _footage),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 22, 24, 20),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Back to welcome',
                            onPressed: () => context.go('/'),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Expanded(
                            child: Align(
                              alignment: Alignment.center,
                              child: TradeIqLogo(size: 36),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _entrance(
                        context,
                        Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Color(0xF2101216),
                            border: Border.fromBorderSide(
                              BorderSide(color: Color(0xFF262B33)),
                            ),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(AppColors.radiusPanel),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x4D000000),
                                blurRadius: 40,
                                offset: Offset(0, -8),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 35, 24, 28),
                            child: _form(context, glass: false),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _form(BuildContext context, {required bool glass}) {
    final session = ref.watch(sessionControllerProvider);
    final colors = context.colors;
    final labelColor = glass ? colors.ink2 : AppColors.textSecondary;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (glass) ...[
            const Kicker('WELCOME BACK'),
            const SizedBox(height: 8),
            Text(
              'Sign in',
              style: LumenGlass.title(color: context.lumen.ink, size: 28),
            ),
            const SizedBox(height: 6),
            Text(
              'Use your TradeIQ work account.',
              style: TextStyle(fontSize: 13.5, color: colors.ink3),
            ),
            const SizedBox(height: 24),
          ] else ...[
            const Text(
              'Sign in',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 29),
          ],
          _FieldLabel('Email', color: labelColor),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            decoration: const InputDecoration(
              hintText: 'you@company.com',
              prefixIcon: Icon(Icons.mail_outline, size: 20),
            ),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Email is required'
                : null,
          ),
          const SizedBox(height: 19),
          _FieldLabel('Password', color: labelColor),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
              ),
            ),
            validator: (value) => (value == null || value.isEmpty)
                ? 'Password is required'
                : null,
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Transform.translate(
                offset: const Offset(-7, 0),
                child: Checkbox(
                  value: _rememberMe,
                  visualDensity: VisualDensity.compact,
                  onChanged: (value) =>
                      setState(() => _rememberMe = value ?? false),
                ),
              ),
              // Expanded, not a Spacer: on a narrow phone the label gives way
              // before the row overflows.
              Expanded(
                child: Text(
                  'Remember me',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: labelColor, fontSize: 14),
                ),
              ),
              TextButton(
                onPressed: () => _showUnavailableMessage('Password reset'),
                style: TextButton.styleFrom(
                  foregroundColor: glass
                      ? context.lumen.accentInk
                      : AppColors.blueLight,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (session.hasError) ...[
            glass
                ? _GlassError(loginErrorMessage(session.error!))
                : Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0x1FFF6B7A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x66FF6B7A)),
                    ),
                    child: Text(
                      loginErrorMessage(session.error!),
                      style: const TextStyle(
                        color: Color(0xFFFFB3BA),
                        fontSize: 13,
                      ),
                    ),
                  ),
            const SizedBox(height: 14),
          ],
          if (glass)
            GlassPrimaryButton(
              label: 'Sign in',
              trailingIcon: Icons.arrow_forward,
              onPressed: _submit,
              busy: _isSubmitting,
            )
          else
            PrimaryActionButton(
              label: 'Sign in',
              onPressed: _submit,
              isLoading: _isSubmitting,
            ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label, {required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// A failed sign-in on glass: an opaque crit wash, so the words clear AA on
/// their own, and a glyph beside them so it never rests on colour.
class _GlassError extends StatelessWidget {
  const _GlassError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final crit = LumenStatus.crit.swatchOf(colors);
    return Container(
      key: const ValueKey('login-error'),
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: Color.alphaBlend(crit.tint, colors.surface1),
        borderRadius: BorderRadius.circular(LumenGlass.radiusIconTile),
        border: Border.all(color: crit.rim),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: colors.crit),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: crit.ink,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
