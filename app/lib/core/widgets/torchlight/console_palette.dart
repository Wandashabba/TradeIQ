import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../l10n/l10n.dart';
import '../../theme/torchlight/tiq_skin.dart';
import '../nav_destinations.dart';

/// THE CONSOLE'S MENU, ON A DESK — a command palette.
///
/// > *"I don't like this menu on desktop… make it dynamic and very creative"*
/// > — the owner, 6 October 2026, choosing **B, the command palette** out of
/// > three directions.
///
/// On a phone the menu is [showTorchMenuSheet]: groups that fold, one open at
/// a time, because a thumb reaching twenty-four destinations needs them
/// collapsed. A desk inherited that sheet stretched across the window — rows a
/// metre wide with one word on each, starting halfway down a 900dp screen.
///
/// A palette is the shape the same list wants when there is a keyboard in
/// front of it. Two letters beat any amount of folding: at fourteen
/// destinations and thirteen territories, typing is faster than aiming, and it
/// is the only form that can hold BOTH in one list.
///
/// ## It carries the scope, and that is half the point
///
/// Changing territory meant opening a second stretched sheet, and the owner
/// reported on the same day that they could not do it on a desk at all. The
/// palette takes [scopes] so the two questions a manager actually has —
/// *where do I go* and *what am I looking at* — are answered by the same
/// keystroke. Nothing in here reaches for territory data itself: this is a
/// core widget and territories are a feature, so the caller that has them
/// passes them in, the same way [showTorchMenuSheet] already takes `lead`.
///
/// ## No amber
///
/// The selected row is drawn in ink — `edgeControl` for its edge, `raised` for
/// its ground. A palette is a list of places, not a commit, and the console's
/// budget of two lit objects is spent on the screen underneath it. The same
/// reasoning as the trough's focus rule in §15.5: focus is ink.
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

  /// The territories, or whatever else this screen can scope to. Empty on a
  /// screen that has no scope, which is most of them.
  final List<PaletteScope> scopes;

  /// Hand the typed text to Ask TradeIQ. Null hides the row rather than
  /// offering something that will not happen.
  final void Function(String query)? onAsk;

  /// Where we are, so the current destination can be marked. Null marks none.
  final String? currentRoute;

  @override
  State<ConsolePalette> createState() => _ConsolePaletteState();
}

/// One thing the palette can scope the screen to — a territory, today.
class PaletteScope {
  const PaletteScope({required this.id, required this.label, required this.onSelect, this.meta});

  final String id;
  final String label;

  /// A figure that earns its place: "31 outlets". Null prints nothing rather
  /// than a dash, because a scope with no count is not a scope with zero.
  final String? meta;

  final VoidCallback onSelect;
}

class _ConsolePaletteState extends State<ConsolePalette> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _keys = FocusNode(debugLabel: 'console-palette-keys');
  int _cursor = 0;

  @override
  void dispose() {
    _query.dispose();
    _keys.dispose();
    super.dispose();
  }

  /// Everything the current query matches, flattened in the order it is drawn
  /// — which is also the order the arrow keys walk, so the cursor and the eye
  /// never disagree.
  List<_Row> get _rows {
    final q = _query.text.trim().toLowerCase();
    final l10n = context.l10n;
    final rows = <_Row>[];

    bool hit(String s) => q.isEmpty || s.toLowerCase().contains(q);

    final destinations = managerDestinations.where((d) => hit(d.label)).toList();
    if (destinations.isNotEmpty) {
      rows.add(_Row.header(l10n.paletteSectionDestinations));
      for (final d in destinations) {
        rows.add(
          _Row.item(
            id: 'dest-${d.route}',
            label: d.label,
            meta: null,
            here: d.route == widget.currentRoute,
            onSelect: () => widget.onGo(d.route),
          ),
        );
      }
    }

    final scopes = widget.scopes.where((s) => hit(s.label)).toList();
    if (scopes.isNotEmpty) {
      rows.add(_Row.header(l10n.paletteSectionScope));
      for (final s in scopes) {
        rows.add(
          _Row.item(
            id: 'scope-${s.id}',
            label: s.label,
            meta: s.meta,
            here: false,
            onSelect: s.onSelect,
          ),
        );
      }
    }

    final onAsk = widget.onAsk;
    if (onAsk != null && q.isNotEmpty) {
      rows.add(_Row.header(l10n.paletteSectionAsk));
      rows.add(
        _Row.item(
          id: 'ask',
          label: l10n.paletteAskFor(_query.text.trim()),
          meta: null,
          here: false,
          onSelect: () => onAsk(_query.text.trim()),
        ),
      );
    }

    return rows;
  }

  List<int> _selectable(List<_Row> rows) => <int>[
    for (var i = 0; i < rows.length; i += 1)
      if (!rows[i].isHeader) i,
  ];

  void _move(int by) {
    final rows = _rows;
    final pick = _selectable(rows);
    if (pick.isEmpty) return;
    final at = pick.indexOf(_cursor);
    // From nowhere, an arrow lands on the first row rather than doing nothing:
    // the keyboard should never need a mouse click to get started.
    final next = at < 0 ? 0 : (at + by).clamp(0, pick.length - 1);
    setState(() => _cursor = pick[next]);
  }

  void _activate() {
    final rows = _rows;
    if (_cursor < 0 || _cursor >= rows.length) return;
    final row = rows[_cursor];
    if (row.isHeader) return;
    row.onSelect!();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _move(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
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
    final rows = _rows;

    // The cursor is kept on a row that still exists: typing narrows the list
    // under it, and a stale index would activate whatever slid into the slot.
    final pick = _selectable(rows);
    if (pick.isNotEmpty && !pick.contains(_cursor)) {
      _cursor = pick.first;
    }

    return Focus(
      focusNode: _keys,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Align(
        alignment: const Alignment(0, -0.62),
        child: ConstrainedBox(
          key: const ValueKey<String>('palette-card'),
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 560),
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
                _Field(controller: _query, hint: l10n.paletteHint, onChanged: (_) => setState(() {})),
                Container(height: skin.depth.borderWidth, color: p.hairline),
                Flexible(
                  child: rows.isEmpty
                      ? Padding(
                          padding: EdgeInsets.all(skin.space.blockGap),
                          child: Text(
                            l10n.paletteNoMatch,
                            style: skin.text.body.style(color: p.ink3),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.symmetric(vertical: skin.space.intraBlock),
                          itemCount: rows.length,
                          itemBuilder: (context, i) => rows[i].isHeader
                              ? Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    skin.space.blockGap,
                                    skin.space.intraBlock,
                                    skin.space.blockGap,
                                    TiqSpace.s2,
                                  ),
                                  child: Text(
                                    rows[i].label,
                                    style: skin.text.eyebrow.style(color: p.ink3),
                                  ),
                                )
                              : _ItemRow(
                                  row: rows[i],
                                  selected: i == _cursor,
                                  onHover: () => setState(() => _cursor = i),
                                ),
                        ),
                ),
                Container(height: skin.depth.borderWidth, color: p.hairline),
                _Legend(
                  move: l10n.paletteKeysMove,
                  open: l10n.paletteKeysOpen,
                  close: l10n.paletteKeysClose,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row {
  const _Row._({required this.label, required this.isHeader, this.meta, this.here = false, this.onSelect, this.id});

  factory _Row.header(String label) => _Row._(label: label, isHeader: true);

  factory _Row.item({
    required String id,
    required String label,
    required String? meta,
    required bool here,
    required VoidCallback onSelect,
  }) => _Row._(id: id, label: label, meta: meta, here: here, isHeader: false, onSelect: onSelect);

  final String? id;
  final String label;
  final String? meta;
  final bool here;
  final bool isHeader;
  final VoidCallback? onSelect;
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.hint, required this.onChanged});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: EdgeInsets.all(skin.space.blockGap),
      child: EditableText(
        key: const ValueKey<String>('palette-query'),
        controller: controller,
        focusNode: FocusNode()..requestFocus(),
        style: skin.text.body.style(color: skin.palette.ink1),
        cursorColor: skin.palette.edgeControl,
        backgroundCursorColor: skin.palette.hairline,
        onChanged: onChanged,
        autofocus: true,
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.row, required this.selected, required this.onHover});

  final _Row row;
  final bool selected;
  final VoidCallback onHover;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: row.onSelect,
        child: MouseRegion(
          onEnter: (_) => onHover(),
          cursor: SystemMouseCursors.click,
          child: Container(
            key: ValueKey<String>('palette-row-${row.id}'),
            constraints: BoxConstraints(minHeight: skin.space.tapTarget),
            padding: EdgeInsets.symmetric(
              horizontal: skin.space.blockGap,
              vertical: TiqSpace.s2,
            ),
            // Ink, never amber: see the class note.
            color: selected ? p.raised : null,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    row.label,
                    style: selected || row.here
                        ? skin.text.bodyStrong.style(color: p.ink1)
                        : skin.text.body.style(color: p.ink2),
                  ),
                ),
                if (row.meta != null)
                  Text(row.meta!, style: skin.text.monoIdent.style(color: p.ink3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.move, required this.open, required this.close});

  final String move;
  final String open;
  final String close;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final style = skin.text.monoIdent.style(color: skin.palette.ink3);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: skin.space.blockGap,
        vertical: TiqSpace.s2,
      ),
      child: Row(
        children: <Widget>[
          Text('↑↓ $move', style: style),
          SizedBox(width: skin.space.blockGap),
          Text('↵ $open', style: style),
          SizedBox(width: skin.space.blockGap),
          Text('esc $close', style: style),
        ],
      ),
    );
  }
}
