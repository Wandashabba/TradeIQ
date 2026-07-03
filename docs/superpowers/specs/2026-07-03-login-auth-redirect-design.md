# Login Form + Router Auth-Redirect — Design Spec

Date: 2026-07-03
Status: Approved

## 1. Purpose

Close [issue #5](https://github.com/Wandashabba/TradeIQ/issues/5): the Flutter
login screen is currently a static placeholder, and the router never reacts
to authentication state. This makes the app's own "proof-of-concept vertical
slice" (login → JWT → outlets) unreachable through the real UI — it's only
provable via widget tests and manual API calls today. This spec wires a real
login form and role-based, fully-guarded router redirects.

## 2. Scope

In scope:
- A real login form (email/password) that calls `SessionController.login()`
- Router redirect logic that guards `/dashboard`, `/audit`, and `/outlets`
  (unauthenticated → `/login`) and routes a freshly-authenticated user to the
  correct landing page by role
- A logout action (dashboard + audit app bars) that clears the session and
  returns to `/login`

Explicitly out of scope (deferred, not part of this change):
- Persistent session storage across app restarts (stays in-memory only, as
  today — `flutter_secure_storage` was removed as an unused dependency and
  is not being re-added here; a restart/refresh logs the user out, and the
  redirect logic sends them back to `/login`, which is correct behavior for
  an in-memory-only session)
- Any change to `/outlets`'s own role restrictions (still open to any
  authenticated role, per the existing "no requireRole restriction yet"
  comment in the backend `outlets.routes.ts` — this spec only adds the
  *authenticated-or-not* gate at the router level, not role-based route
  restrictions beyond the initial post-login landing page)

## 3. Architecture: Riverpod-driven GoRouter redirect

GoRouter's `redirect` callback re-runs whenever navigation occurs, but it
also needs to re-run when *session state* changes outside of navigation
(e.g. right after `SessionController.login()` resolves). GoRouter supports
this via a `refreshListenable: Listenable` constructor argument — passing a
`Listenable` that calls `notifyListeners()` on relevant state changes causes
GoRouter to re-evaluate `redirect` immediately.

Implementation:
- `app/lib/core/router/session_refresh_listenable.dart` (new): a
  `SessionRefreshListenable extends ChangeNotifier` that takes a `Ref` and
  calls `ref.listen(sessionControllerProvider, (_, __) => notifyListeners())`
  in its constructor.
- `app/lib/core/router/app_router.dart` (modified): `buildRouter()` becomes
  `routerProvider = Provider<GoRouter>((ref) { ... })`, constructing a
  `SessionRefreshListenable(ref)` and passing it as `refreshListenable`, plus
  a `redirect:` callback (logic below). The existing route list
  (`/login`, `/dashboard`, `/audit`, `/outlets`) is unchanged.
- `app/lib/main.dart` (modified): `TradeIqApp` becomes a `ConsumerWidget`;
  `routerConfig: buildRouter()` becomes `routerConfig: ref.watch(routerProvider)`.

Redirect logic (pseudocode, exact implementation may vary slightly):

```dart
redirect: (context, state) {
  final session = ref.read(sessionControllerProvider).valueOrNull;
  final isLoggedIn = session?.role != null;
  final isOnLoginScreen = state.matchedLocation == '/login';

  if (!isLoggedIn) {
    return isOnLoginScreen ? null : '/login';
  }
  if (isOnLoginScreen) {
    return session!.role == 'field_agent' ? '/audit' : '/dashboard';
  }
  return null; // no redirect needed
}
```

`/outlets` is reachable by any authenticated role once past this gate,
matching its current (unrestricted) backend authorization.

## 4. Login form

`app/lib/features/auth/presentation/login_screen.dart` becomes a
`ConsumerStatefulWidget`:
- A `Form` with two `TextFormField`s (email, password — password obscured),
  basic non-empty validation, and a submit button.
- On submit: calls
  `ref.read(sessionControllerProvider.notifier).login(email, password)`.
  No manual navigation call here — the redirect logic (§3) reacts to the
  resulting state change automatically once `SessionController` transitions
  out of `AsyncLoading`.
- While `ref.watch(sessionControllerProvider)` is `AsyncLoading`: submit
  button shows a spinner and is disabled.
- While it's `AsyncError`: an inline error message renders below the form
  (e.g. "Invalid credentials" — the actual backend error message is
  surfaced, not a generic string, since `auth.routes.ts` already returns a
  clean `{error: "Invalid credentials"}` body distinguishable from a network
  failure).

## 5. Logout

`SessionController` gains a `logout()` method:
```dart
void logout() {
  currentAuthToken = null;
  state = const AsyncData(SessionState());
}
```
This is synchronous (no repository call needed — logout is purely local
state teardown). Setting `state` to an empty `SessionState()` makes
`isLoggedIn` false on the next redirect evaluation, which the
`SessionRefreshListenable` immediately triggers, sending the user back to
`/login`.

`DashboardShellScreen` and `AuditShellScreen` each gain a logout
`IconButton` (`Icons.logout`) in their `AppBar.actions`, calling
`ref.read(sessionControllerProvider.notifier).logout()`. Both widgets
change from their current base classes to Riverpod-aware equivalents
(`DashboardShellScreen`: `StatelessWidget` → `ConsumerWidget`;
`AuditShellScreen`: keeps its existing `StatefulWidget` for stepper index
state, gains `ConsumerState`/`ref` access via `ConsumerStatefulWidget`).

## 6. Testing

- `app_router_test.dart` (modified): wrap in `ProviderScope`, read
  `ref.read(routerProvider)` instead of calling `buildRouter()` directly.
  Existing assertion (unauthenticated → login screen renders) still holds.
- New: redirect-guard tests — unauthenticated request to `/dashboard`
  resolves to the login screen; authenticated `field_agent` session
  overriding `sessionControllerProvider` lands on `/audit` when starting
  from `/login`; authenticated `manager` lands on `/dashboard`.
- New: login screen widget tests — entering credentials and submitting
  calls `login()` on a fake repository (reusing the `FakeAuthRepository`/
  `FailingAuthRepository` pattern from `session_controller_test.dart`);
  loading state disables the submit button; error state renders the error
  text.
- New: logout test — calling `logout()` after a successful fake login
  resets state to an empty `SessionState()`.
- Full `flutter test` suite must stay green; `flutter analyze` clean.

## 7. Explicitly out of scope for this spec

- Session persistence across restarts (see §2)
- Role-based restrictions on `/outlets` itself (see §2)
- Any backend changes — this is Flutter-only; `auth.routes.ts` and
  `SessionController.login()`'s existing behavior are unchanged
