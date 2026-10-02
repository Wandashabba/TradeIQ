import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/motion_budget.dart';
import '../theme/torchlight/tiq_skin.dart';

/// HOW A ROUTE ARRIVES. One helper, both roles, three kinds.
///
/// Before this existed the manager console had a 250ms shared-axis on 36
/// routes and the agent had *nothing* — every agent screen fell through to
/// `MaterialPage`'s platform default, which on web is an abrupt swap. That was
/// not a decision that the two sides should feel different; it was the absence
/// of one, recorded in the old helper's own doc comment ("Agent/public routes
/// do not use this helper"). A page transition by omission is the same class
/// of bug as a colour by omission.
///
/// ## The rule: does the route carry the nav bar?
///
/// **A route that carries the nav bar is a peer. A route that does not is
/// something you went into.** That is the whole taxonomy, and it is checkable
/// against the source rather than being a matter of taste:
///
/// * `ConsoleFrame` / `TorchShell(navPill: …)` ⇒ the destination bar is on
///   screen before and after, so the person moved **sideways**. Peer.
/// * No nav bar — a detail, a form, the capture flow, a settings screen with a
///   back chip ⇒ a new surface arrived **over** the destination they were on,
///   and the back chip says they can come back out. Forward.
///
/// The two shapes then take the two halves of Material's shared axis, which is
/// exactly what that axis is for:
///
/// | kind | motion | when |
/// |---|---|---|
/// | [TorchPageKind.peer] | shared axis **horizontal** | sideways between destinations that both wear the nav bar |
/// | [TorchPageKind.forward] | shared axis **scaled** (Z) | into a detail, a form or the capture flow, over the destination you were on |
/// | [TorchPageKind.arrival] | fade | the ground changed under you and there is no back |
///
/// [TorchPageKind.arrival] is the one that is not about hierarchy. A slide
/// implies a spatial relationship to a screen you can return to; sign-in after
/// the splash, the screen a refused build gets, and the outcome of a submitted
/// visit have none. They are cross-faded — which is what the splash → sign-in
/// hand-off was already doing by hand before this helper existed.
///
/// ## Duration and curve are tokens, not literals
///
/// [TiqMotion.reveal] — 320ms, declared as "plate reveal, sheet, **route**".
/// The old helper's `Duration(milliseconds: 250)` was a literal that no token
/// backed; `TorchSheet` has been resolving its own route through `reveal` the
/// whole time, so a sheet and a page were arriving at two different speeds on
/// the same screen. Nothing new was added to [TiqMotion] for this change.
///
/// ## Reduced motion
///
/// [MotionBudget.still] — `MediaQuery.disableAnimations` (and, when #407
/// lands, battery saver) — replaces all three with a cross-fade on the same
/// curve. Never an instant cut *and* never a slide: a cross-fade still tells
/// you the screen changed, which is the information the transition carries,
/// without the travel that is the part people ask to turn off.
///
/// ## What it costs
///
/// One opacity layer per page **while the transition runs**, and none at rest.
/// `SharedAxisTransition` and `FadeTransition` both composite through
/// `Opacity`, which is a `saveLayer` on the raster side — but only for the
/// 320ms, only on a route that is not interactive while it moves, and the
/// paint budget's "zero `saveLayer`" is a statement about the resting frame
/// (see `chrome_golden_test.dart`, which asserts the frame, not the
/// transition). No `BackdropFilter`, no `ShaderMask`, no `ImageFiltered`, no
/// `ColorFiltered` is introduced by any of the three.
enum TorchPageKind {
  /// Sideways, between two destinations that both wear the nav bar.
  peer,

  /// Into something, over the destination you were on. It has a back chip.
  forward,

  /// The ground changed. There is no back.
  arrival,
}

/// A go_router page for a Torchlight route. See [TorchPageKind] for the rule
/// that picks [kind].
CustomTransitionPage<void> torchPage(
  Widget child, {
  LocalKey? key,
  TorchPageKind kind = TorchPageKind.peer,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: TiqMotion.reveal,
    reverseTransitionDuration: TiqMotion.reveal,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // The ground the two pages cross over. `skin.palette.ground` and not
      // `context.colors.plane`: the legacy slot is only `ground` because
      // `TiqColors.fromSkin` maps it there, and a transition that reads the
      // shim is a transition that breaks on the day the shim is deleted.
      final fill = context.skin.palette.ground;

      if (MotionBudget.of(context).still) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: TiqMotion.enterCurve,
          ),
          child: child,
        );
      }

      return switch (kind) {
        TorchPageKind.peer => SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.horizontal,
          fillColor: fill,
          child: child,
        ),
        TorchPageKind.forward => SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.scaled,
          fillColor: fill,
          child: child,
        ),
        TorchPageKind.arrival => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: TiqMotion.enterCurve,
          ),
          child: child,
        ),
      };
    },
  );
}
