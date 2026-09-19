import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import '../mark/tiq_mark.dart';
import 'empty_drawing.dart';

/// Whether the failure took the screen or only a region of it.
enum ErrorScope {
  /// Nothing loaded. A drawing, a headline, what it means for the user's work,
  /// and one action.
  wholeScreen,

  /// One region failed and the rest of the screen is fine. No drawing, no
  /// panel, no card, no red fill — a triangle, two lines and a ghost Retry at
  /// the region's own height.
  inline,
}

/// THE CLOSED SET OF FAILURES, AND THE SENTENCE EACH ONE GETS.
///
/// A raw exception in front of a user is a bug with a stack trace attached,
/// and `SocketException: Failed host lookup: 'api.tradeiq.co.za'` tells an
/// agent in a back aisle nothing except that the app is broken. Every failure
/// this product can show maps onto one of these, and the mapping is a
/// function ([TorchErrorMessage.forKind]) rather than a string built at the
/// call site.
enum TorchErrorKind {
  /// No signal. There is **no Retry** — a retry with no signal is theatre.
  network,

  /// 5xx. The work is held; Retry is real.
  server,

  /// 4xx. Never a bare Retry: retrying an unchanged rejection fails
  /// identically. The action opens the offending field.
  rejected,

  /// 413. The photo is resized and tried again.
  tooLarge,

  /// 403 on a resource. Not a Retry — a request for access.
  permission,

  /// Anything else. Carries the code, and is logged: an unknown that recurs
  /// is a ticket.
  unknown,
}

/// The sanitised message for a failure.
@immutable
class TorchErrorMessage {
  const TorchErrorMessage({
    required this.kind,
    required this.headline,
    required this.body,
    required this.offersRetry,
    this.code,
  });

  final TorchErrorKind kind;

  /// What failed, in the user's terms.
  final String headline;

  /// What it means for their work — and it **names the work's safety first**,
  /// because that is the sentence an agent with six captured sections needs
  /// before anything else.
  final String body;

  /// Whether a Retry is honest for this kind.
  final bool offersRetry;

  /// A support code in `mono.ident`. Dropped entirely in Veld: a support code
  /// is unreadable in glare and useless to an agent on a shelf.
  final String? code;

  /// The English defaults. A localised screen passes its own strings through
  /// [ErrorState]; the shape is what is fixed here.
  static TorchErrorMessage forKind(
    TorchErrorKind kind, {
    String? code,
    String? detail,
  }) => switch (kind) {
    TorchErrorKind.network => TorchErrorMessage(
      kind: kind,
      headline: 'No signal',
      body: 'Your work is held on this phone and sends itself.',
      offersRetry: false,
      code: code,
    ),
    TorchErrorKind.server => TorchErrorMessage(
      kind: kind,
      headline: 'The server is having trouble',
      body: 'Your work is held on this phone. Nothing is lost.',
      offersRetry: true,
      code: code,
    ),
    TorchErrorKind.rejected => TorchErrorMessage(
      kind: kind,
      headline: 'The server would not take this',
      body: detail ?? 'One of the values needs fixing before it can be sent.',
      offersRetry: false,
      code: code,
    ),
    TorchErrorKind.tooLarge => TorchErrorMessage(
      kind: kind,
      headline: 'This photo is too big to send as it is',
      body: 'We will resize it and try again.',
      offersRetry: true,
      code: code,
    ),
    TorchErrorKind.permission => TorchErrorMessage(
      kind: kind,
      headline: 'You do not have access to this',
      body: 'Ask the account owner to give you access.',
      offersRetry: false,
      code: code,
    ),
    TorchErrorKind.unknown => TorchErrorMessage(
      kind: kind,
      headline: 'Something went wrong',
      body: 'Your work is held on this phone.',
      offersRetry: true,
      code: code,
    ),
  };

  /// Map an HTTP status onto a kind. The one place a number becomes a
  /// sentence.
  static TorchErrorKind kindForStatus(int status) {
    if (status == 413) return TorchErrorKind.tooLarge;
    if (status == 401 || status == 403) return TorchErrorKind.permission;
    if (status >= 500) return TorchErrorKind.server;
    if (status >= 400) return TorchErrorKind.rejected;
    return TorchErrorKind.unknown;
  }

  /// SANITISE. Takes anything a `catch` produced and returns something a
  /// person can read.
  ///
  /// It deliberately **ignores** the object's own `toString`. There is no
  /// allowlist of "safe" exceptions and no attempt to pretty-print one: a
  /// message that is sometimes an exception is a message that will one day
  /// carry a host name, a file path or a token into a screenshot in a
  /// WhatsApp group. The only thing crossing this boundary is the kind and,
  /// where the caller supplies one, a code.
  static TorchErrorMessage sanitise(Object? error, {int? status}) {
    final kind = status == null
        ? TorchErrorKind.unknown
        : kindForStatus(status);
    assert(() {
      if (error != null) {
        debugPrint('TorchErrorMessage.sanitise swallowed: $error');
      }
      return true;
    }());
    return forKind(kind, code: status == null ? null : 'HTTP $status');
  }
}

/// A FAILURE THE USER CAN ACT ON.
///
/// ```dart
/// ErrorState(
///   message: TorchErrorMessage.forKind(TorchErrorKind.server, code: 'HTTP 503'),
///   action: TorchPrimaryButton(label: 'Try again', claimId: 'retry', onPressed: …),
/// )
/// ```
///
/// **One Retry per region.** Two retries in one region is two buttons that do
/// the same thing, and a user who presses both fires the request twice.
/// [TorchErrorRegion] asserts it in debug.
///
/// **There is no amber warning anywhere in this product**, and a failure is
/// the single most tempting place to break that rule. Severity is crimson at
/// two commitment levels plus a silhouette plus a word. Where this block
/// carries a primary action, that action declares its claim like any other
/// primary and is granted or denied by `TorchScope` — the block itself emits
/// nothing.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.scope = ErrorScope.wholeScreen,
    this.drawing = EmptyDrawing.envelope,
    this.action,
    this.attempts = 0,
  });

  final TorchErrorMessage message;
  final ErrorScope scope;

  /// The same closed enum of three as the empty state — in `bad` rather than
  /// `edgeControl`, with a filled triangle at its lower right. Whole-screen
  /// only.
  final EmptyDrawing drawing;

  /// The one action. Null where the kind offers none (no signal).
  final Widget? action;

  /// After a second failure the count is stated rather than the message
  /// repeated: "Tried 3 times" is information, and three identical error
  /// blocks are noise.
  final int attempts;

  /// Below twice this, the inline action drops beneath the words instead of
  /// sitting beside them. It is the width of a two-word ghost action plus its
  /// 48dp target — narrower than that and the sentence is a column of single
  /// words.
  static const double _actionFloor = 96;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final whole = scope == ErrorScope.wholeScreen;
    final veld = skin.density == TiqDensity.veld;

    assert(() {
      if (action != null) {
        TorchErrorRegion.debugRegisterAction(context);
      }
      return true;
    }());

    if (!whole) {
      final words = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(message.headline, style: skin.text.body.style(color: p.ink1)),
          const SizedBox(height: TiqSpace.s1),
          Text(message.body, style: skin.text.meta.style(color: p.ink3)),
          if (attempts > 1) ...<Widget>[
            const SizedBox(height: TiqSpace.s1),
            Text(
              'Tried $attempts times',
              style: skin.text.meta.style(color: p.ink3),
            ),
          ],
        ],
      );

      return Semantics(
        liveRegion: true,
        container: true,
        child: Container(
          constraints: BoxConstraints(minHeight: skin.space.tapTarget),
          padding: const EdgeInsets.symmetric(vertical: TiqSpace.s2),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // "Trailing or beneath, whichever fits." Measured on the real
              // width, never on a text-scale guess: at 2.0× in Afrikaans a
              // Retry beside two wrapped lines has nowhere to be, and a Retry
              // that has been pushed off the right edge of a region is a
              // failure the reader cannot act on.
              final glyph = MarkScale.glyph(context, 12);
              final room =
                  constraints.maxWidth - glyph - TiqSpace.s3 - TiqSpace.s3;
              final beneath =
                  action != null && (!room.isFinite || room < _actionFloor * 2);

              final lead = Padding(
                padding: const EdgeInsets.only(top: 2),
                child: TiqMark(
                  shape: MarkShape.watchTriangle,
                  color: p.bad,
                  size: glyph,
                ),
              );

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  lead,
                  const SizedBox(width: TiqSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        words,
                        if (beneath) ...<Widget>[
                          const SizedBox(height: TiqSpace.s2),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: action!,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (action != null && !beneath) ...<Widget>[
                    const SizedBox(width: TiqSpace.s3),
                    Flexible(child: action!),
                  ],
                ],
              );
            },
          ),
        ),
      );
    }

    return Semantics(
      liveRegion: true,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              EmptyStateDrawing(drawing: drawing, color: p.bad),
              Positioned(
                right: -2,
                bottom: -2,
                child: TiqMark(
                  shape: MarkShape.criticalTriangle,
                  color: p.bad,
                  size: MarkScale.glyph(context, 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: TiqSpace.s6),
          Semantics(
            header: true,
            child: Text(
              message.headline,
              style: skin.text.titleL.style(color: p.ink1),
            ),
          ),
          const SizedBox(height: TiqSpace.s2),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: skin.text.body.size * 32),
            child: Text(
              message.body,
              style: skin.text.body.style(color: p.ink2),
            ),
          ),
          // The code is for support, and Veld drops it: unreadable in glare,
          // useless to an agent on a shelf.
          if (message.code != null && !veld) ...<Widget>[
            const SizedBox(height: TiqSpace.s2),
            Text(
              message.code!,
              style: skin.text.monoIdent.style(color: p.ink3),
            ),
          ],
          if (attempts > 1) ...<Widget>[
            const SizedBox(height: TiqSpace.s1),
            Text(
              'Tried $attempts times',
              style: skin.text.meta.style(color: p.ink3),
            ),
          ],
          if (action != null) ...<Widget>[
            const SizedBox(height: TiqSpace.s6),
            if (veld)
              SizedBox(width: double.infinity, child: action!)
            else
              Align(alignment: Alignment.centerLeft, child: action!),
          ],
        ],
      ),
    );
  }
}

/// ONE RETRY PER REGION.
///
/// Wrap a screen's failable region in this and a second [ErrorState] with an
/// action inside it asserts in debug. It does nothing in release: a design
/// rule must never throw in front of a user in a back aisle during Stage 6.
///
/// ```dart
/// TorchErrorRegion(
///   name: 'territory scores',
///   child: …,
/// )
/// ```
class TorchErrorRegion extends InheritedWidget {
  TorchErrorRegion({super.key, required this.name, required super.child});

  /// What the region holds, for the assertion's message.
  final String name;

  final List<Element> _actions = <Element>[];

  static void debugRegisterAction(BuildContext context) {
    final region = context
        .getInheritedWidgetOfExactType<TorchErrorRegion>();
    if (region == null) return;
    final element = context as Element;
    if (region._actions.contains(element)) return;
    region._actions.add(element);
    if (region._actions.length > 1) {
      throw FlutterError(
        'Two retryable errors in one region ("${region.name}").\n\n'
        'One Retry per region. Two buttons that do the same thing is a user '
        'pressing both and a request firing twice; it is also two different '
        'accounts of what failed, in the same place, at the same time. '
        'Render the region\'s failure once, at the region\'s own height.',
      );
    }
  }

  @override
  bool updateShouldNotify(TorchErrorRegion oldWidget) => false;
}
