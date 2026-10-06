import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../l10n/l10n.dart';
import '../../theme/torchlight/tiq_skin.dart';
import '../nav_destinations.dart';
import 'input/filter_chip.dart';

/// THE CONSOLE'S MENU, ON A DESK — one screenful, nothing scrolls.
///
/// > *"Now the scrolling on the menu is too long, I need it to be shorter and
/// > nicer… this is a professional app, we don't need these."* — the owner,
/// > 6 October 2026, choosing **Short C, territories as chips**, and striking
/// > the keyboard legend.
///
/// The first palette was a single vertical list: thirteen territories, then
/// fourteen destinations, then a row of key hints. It scrolled, and the owner
/// said so. This is the same two lists laid out so that neither needs to:
///
/// * **Territories as chips**, wrapping. Thirteen names take five lines
///   instead of thirteen rows, and the one in scope is drawn selected.
/// * **Destinations as a four-column grid.** The seventeen a manager uses in a
///   day take five lines; the seven `configure` pages are reached by typing.
///
/// With the search line that is one card of roughly 650dp, which fits the
/// 660dp a maximised laptop browser actually has. The drawing said four lines
/// of chips and three columns in a 640 card; the notes on the width and the
/// grid say, with numbers, why it is 900 and four here.
///
/// ## The legend is gone, the shortcuts are not
///
/// `↑↓ move · ↵ open · esc close` is deleted. Arrow keys still walk the chips
/// and then the cells, Enter still activates, Escape still closes — they are
/// simply not announced. A professional tool does not caption its own
/// keyboard, and the owner's words are the whole argument.
///
/// ## The one place this departs from the drawing
///
/// The artwork filled the in-scope chip amber. The product's own chip,
/// [TorchFilterChip], is **never amber** by rule (unify §1.6, in its doc): a
/// flame edge on a row of chips is the repeated-fill violation the amber law
/// exists to prevent. The in-scope chip is therefore the chip's own selected
/// state — bold, in ink — and this note is here so the difference reads as a
/// decision, not a slip.
///
/// Scope data still travels as [scopes] from the caller: this is a core widget
/// and territories are a feature. The desk's rail already carries sign-out,
/// the password and brightness at its foot ([ConsoleRailFooter]), so unlike the
/// phone's sheet this card does not repeat them.
class ConsolePalette extends StatefulWidget {
  const ConsolePalette({
    super.key,
    required this.onGo,
    this.scopes = const <PaletteScope>[],
    this.onAsk,
    this.currentRoute,
  });

  /// Take me to this route. The caller closes the palette.
  final void Function(String route) onGo;

  /// What this screen can scope to — the territories, today. Empty on a
  /// screen with no scope, and the section is then simply absent.
  final List<PaletteScope> scopes;

  /// Hand the typed text to Ask TradeIQ. Offered only when a query matches
  /// nothing else, so it never competes with a destination or a territory.
  final void Function(String query)? onAsk;

  /// Where we are, so the current destination is emphasised. Null marks none.
  final String? currentRoute;

  @override
  State<ConsolePalette> createState() => _ConsolePaletteState();
}

/// One thing the palette can scope the screen to.
class PaletteScope {
  const PaletteScope({
    required this.id,
    required this.label,
    required this.onSelect,
    this.selected = false,
  });

  final String id;
  final String label;

  /// Whether this is the scope in force. Exactly one of the caller's scopes
  /// should be, and it is drawn as the chip's selected state.
  final bool selected;

  final VoidCallback onSelect;
}

class _ConsolePaletteState extends State<ConsolePalette> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _keys = FocusNode(debugLabel: 'console-palette-keys');

  /// The keyboard cursor, as an index into [_targets]. -1 is nowhere, which is
  /// how the card opens: nothing is pre-chosen until a key says so.
  int _cursor = -1;

  @override
  void dispose() {
    _query.dispose();
    _keys.dispose();
    super.dispose();
  }

  String get _q => _query.text.trim().toLowerCase();

  bool _hit(String s) => _q.isEmpty || s.toLowerCase().contains(_q);

  List<PaletteScope> get _scopes =>
      widget.scopes.where((s) => _hit(s.label)).toList();

  /// At rest, the places a manager goes during a day: `operate` and
  /// `insight`, seventeen of them. `configure` — exception rules, webhooks,
  /// survey templates, the scorecard — is set up once and then left alone, so
  /// its seven are folded until a query names one. Typing searches all 24.
  ///
  /// This is what keeps the grid to five rows. All 24 at three columns is
  /// eight rows and 344dp, and the card was 837dp against a 660dp laptop
  /// viewport — the drawing showed fourteen because it was drawn before the
  /// count was checked.
  List<NavDestination> get _destinations => _q.isEmpty
      ? managerDestinations.where((d) => d.group != NavGroup.configure).toList()
      : managerDestinations.where((d) => _hit(d.label)).toList();

  bool get _showAsk =>
      widget.onAsk != null && _q.isNotEmpty && _scopes.isEmpty && _destinations.isEmpty;

  /// Everything the arrow keys can land on, in drawing order: chips first,
  /// then the grid, then the Ask fallback if it is showing.
  List<_Target> get _targets => <_Target>[
    for (final s in _scopes) _Target('scope-${s.id}', s.onSelect),
    for (final d in _destinations) _Target('dest-${d.route}', () => widget.onGo(d.route)),
    if (_showAsk) _Target('ask', () => widget.onAsk!(_query.text.trim())),
  ];

  void _move(int by) {
    final n = _targets.length;
    if (n == 0) return;
    setState(() => _cursor = _cursor < 0 ? 0 : (_cursor + by).clamp(0, n - 1));
  }

  void _activate() {
    final targets = _targets;
    if (_cursor < 0 || _cursor >= targets.length) return;
    targets[_cursor].onSelect();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.arrowRight:
        _move(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.arrowLeft:
        _move(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        _activate();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        Navigator.of(context).maybePop();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final p = skin.palette;

    final scopes = _scopes;
    final destinations = _destinations;
    final targets = _targets;
    // A query that narrows the list under the cursor must not leave it on a
    // thing that is no longer there.
    if (_cursor >= targets.length) {
      _cursor = targets.isEmpty ? -1 : targets.length - 1;
    }
    final focusedId = _cursor >= 0 && _cursor < targets.length ? targets[_cursor].id : null;
    final showAsk = _showAsk;
    final nothing = scopes.isEmpty && destinations.isEmpty && !showAsk;

    // `TorchShell` provides the DefaultTextStyle every screen relies on; a
    // dialog route lands outside it, so this card provides its own. Without it
    // every row drew in Flutter's yellow, double-underlined debug fallback.
    return DefaultTextStyle(
      style: skin.text.body.style(color: p.ink1),
      child: Focus(
        focusNode: _keys,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Align(
          alignment: const Alignment(0, -0.62),
          child: ConstrainedBox(
            key: const ValueKey<String>('palette-card'),
            // 900, NOT THE 640 THAT WAS DRAWN, and every step is measured.
            //
            // The drawing's chips were 13px type in a 7px pill; the product's
            // chip, [TorchFilterChip], is a 44dp box a finger lands in, with a
            // mark slot reserved whether or not a mark is drawn (its own doc
            // explains both). Rendered at 640 the thirteen territories
            // averaged 247dp each and wrapped to EIGHT rows, not four, and
            // the card overflowed the window by 41dp. The outer box is 44dp
            // whether the chip is quiet or not, so no variant of the chip
            // recovers the height — only width does. At 820 they made six
            // rows; at 900 they make five. With the grid at four columns the
            // whole card is about 650dp, which fits the 660dp a maximised
            // laptop browser actually has.
            constraints: const BoxConstraints(maxWidth: 900),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(skin.radii.card),
                border: Border.all(color: p.edgeStructure, width: skin.depth.borderWidth),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _Field(
                    controller: _query,
                    hint: l10n.paletteHint,
                    onChanged: (_) => setState(() {}),
                  ),
                  Container(height: skin.depth.borderWidth, color: p.hairline),
                  // A guard, not a feature: on any window the card fits, this
                  // never scrolls. On one it does not — a 500dp laptop with the
                  // dock up — it scrolls rather than painting overflow stripes.
                  Flexible(
                    child: SingleChildScrollView(
                      child: Padding(
                    padding: EdgeInsets.all(skin.space.blockGap),
                    child: nothing
                        ? Text(l10n.paletteNoMatch, style: skin.text.body.style(color: p.ink3))
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (scopes.isNotEmpty) ...<Widget>[
                                _Eyebrow(l10n.paletteSectionScope),
                                SizedBox(height: skin.space.intraBlock),
                                Wrap(
                                  spacing: TiqSpace.s2,
                                  runSpacing: TiqSpace.s2,
                                  children: <Widget>[
                                    for (final s in scopes)
                                      _Focusable(
                                        focused: focusedId == 'scope-${s.id}',
                                        // INTRINSIC WIDTH, OR ONE CHIP PER ROW. The
                                        // chip is built for `TorchFilterRail`, a
                                        // horizontal scroller that hands it a tight
                                        // cross-axis; given a loose 592dp it stretched
                                        // to all of it, and thirteen chips became
                                        // thirteen rows — 616dp of chips and a card
                                        // 353dp taller than the window. Its own doc
                                        // names `IntrinsicWidth` chips as the shape
                                        // outside a rail, so that is what these are.
                                        child: KeyedSubtree(
                                          key: ValueKey<String>('palette-row-scope-${s.id}'),
                                          child: IntrinsicWidth(
                                            child: TorchFilterChip(
                                              label: s.label,
                                              selected: s.selected,
                                              onSelected: s.onSelect,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                              if (scopes.isNotEmpty && destinations.isNotEmpty)
                                SizedBox(height: skin.space.blockGap),
                              if (destinations.isNotEmpty) ...<Widget>[
                                _Eyebrow(l10n.paletteSectionGoTo),
                                SizedBox(height: skin.space.intraBlock),
                                // Four columns, not the drawing's three: with
                                // seventeen destinations that is five rows
                                // instead of six, and the longest label shown
                                // at rest ("Visit verification") still fits a
                                // cell with room.
                                _Grid(
                                  columns: 4,
                                  gap: TiqSpace.s2,
                                  children: <Widget>[
                                    for (final d in destinations)
                                      _Cell(
                                        key: ValueKey<String>('palette-row-dest-${d.route}'),
                                        label: d.label,
                                        here: d.route == widget.currentRoute,
                                        focused: focusedId == 'dest-${d.route}',
                                        onTap: () => widget.onGo(d.route),
                                      ),
                                  ],
                                ),
                              ],
                              if (showAsk)
                                _Cell(
                                  key: const ValueKey<String>('palette-row-ask'),
                                  label: l10n.paletteAskFor(_query.text.trim()),
                                  here: false,
                                  focused: focusedId == 'ask',
                                  onTap: () => widget.onAsk!(_query.text.trim()),
                                ),
                            ],
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
}

class _Target {
  const _Target(this.id, this.onSelect);
  final String id;
  final VoidCallback onSelect;
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Text(text, style: skin.text.eyebrow.style(color: skin.palette.ink3));
  }
}

/// Three equal columns, filled in document order, sized from the width the
/// card actually has rather than a fixed cell — so the names never clip.
class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.gap, required this.children});

  final int columns;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final cell = (c.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: <Widget>[
          for (final child in children) SizedBox(width: cell, child: child),
        ],
      );
    },
  );
}

/// One destination in the grid. The current one is emphasised; the keyboard's
/// one carries an ink edge. Both are ink — see the class note on amber.
class _Cell extends StatelessWidget {
  const _Cell({
    super.key,
    required this.label,
    required this.here,
    required this.focused,
    required this.onTap,
  });

  final String label;
  final bool here;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    return Semantics(
      button: true,
      selected: here,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: _Focusable(
            focused: focused,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: TiqSpace.s2),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: here
                    ? skin.text.bodyStrong.style(color: p.ink1)
                    : skin.text.body.style(color: p.ink2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The keyboard cursor, drawn as a hairline edge in ink. A palette is a list
/// of places, not a commit, so it never spends amber. The unfocused edge is
/// fully transparent rather than absent, so focusing never shifts layout.
class _Focusable extends StatelessWidget {
  const _Focusable({required this.focused, required this.child});

  final bool focused;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(skin.radii.control),
        border: Border.all(
          color: focused ? skin.palette.edgeControl : skin.palette.edgeControl.withValues(alpha: 0),
          width: skin.depth.borderWidth,
        ),
      ),
      child: child,
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.hint, required this.onChanged});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;

    return Padding(
      padding: EdgeInsets.all(skin.space.blockGap),
      child: Row(
        children: <Widget>[
          _Glass(color: p.navInkInactive),
          SizedBox(width: skin.space.intraBlock),
          Expanded(
            child: Stack(
              alignment: AlignmentDirectional.centerStart,
              children: <Widget>[
                // `EditableText` draws nothing when empty, and a palette opens
                // empty — so the hint is painted beneath it.
                if (controller.text.isEmpty)
                  Text(hint, style: skin.text.body.style(color: p.inkMute)),
                EditableText(
                  key: const ValueKey<String>('palette-query'),
                  controller: controller,
                  focusNode: FocusNode()..requestFocus(),
                  style: skin.text.body.style(color: p.ink1),
                  cursorColor: p.edgeControl,
                  backgroundCursorColor: p.hairline,
                  onChanged: onChanged,
                  autofocus: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The magnifier, as two strokes. One glyph does not justify an icon font.
class _Glass extends StatelessWidget {
  const _Glass({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(16, 16), painter: _GlassPainter(color));
}

class _GlassPainter extends CustomPainter {
  const _GlassPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(size.width * 0.42, size.height * 0.42), size.width * 0.3, stroke);
    canvas.drawLine(
      Offset(size.width * 0.66, size.height * 0.66),
      Offset(size.width * 0.94, size.height * 0.94),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_GlassPainter old) => old.color != color;
}
