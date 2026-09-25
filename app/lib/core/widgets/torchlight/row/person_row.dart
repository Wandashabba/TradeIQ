import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import 'row_marks.dart';
import 'soft_row.dart';

/// Name a human (#399/#400).
///
/// A configuration of [SoftRow] with two absolute rules and one consequence.
///
/// **Never a database id as the thing a reader reads first.** The name is the
/// title; the role and the outlet are the reason line. Where there is no name
/// the primary line becomes the role and the outlet, and the identifier drops
/// to a third line in `mono.ident` — the one place a raw id is legitimate,
/// because it is then the only fact. A UUID is never a title.
///
/// **Never a photograph.** POPIA, and forty kilobytes of bundle per person.
/// The leading tile carries two uppercase initials on the `well`, or a barred
/// ring when even the initials are unknown — never a generic silhouette icon,
/// which says "person" to a reader who already knows this row is a person.
///
/// The consequence: the name **middle-truncates**. On a 200dp fraud row
/// "Nomsa Dlamini-Mkhize" and "Nomsa Dlamini-Ndlovu" end-truncate to the same
/// string, and the human being was getting less care than the store. The full
/// name is in the semantics label whatever is painted.
///
/// ```dart
/// PersonRow(
///   name: agent.fullName,
///   role: l10n.roleFieldAgent,
///   outlet: agent.outletName,
///   trailingWord: agent.isSelf ? l10n.you : null,
///   onTap: () => context.push(agent.route),
/// )
/// ```
class PersonRow extends StatelessWidget {
  const PersonRow({
    super.key,
    this.name,
    this.role,
    this.outlet,
    this.identifier,
    this.identifierLabel,
    this.unknownLabel,
    this.trailingWord,
    this.trailing,
    this.trailingLabel,
    this.meta,
    this.metaLabel,
    this.actions,
    this.severity,
    this.severityLabel,
    this.deactivated = false,
    this.onTap,
    this.onLongPress,
    this.density = SoftRowDensity.tall,
    this.separator = SoftRowSeparator.auto,
  }) : assert(
         name != null || role != null || outlet != null || unknownLabel != null,
         'PersonRow: with no name, no role and no outlet there is nothing to '
         'show but an id, and an id is never the primary line. Pass '
         'unknownLabel ("Unknown agent") so the row says so in words.',
       ),
       assert(
         trailing == null || trailingWord != null || trailingLabel != null,
         'PersonRow: a figure in the trailing needs trailingLabel. A SoftRow '
         'is ONE semantics node that excludes everything beneath it, so a '
         '"94 pts" painted in the trailing is read by nobody — the row '
         'announces a name and stops, and the number the row exists to '
         'compare is silent. Pass the figure in words ("94 points"); it is '
         'the same defect the worklists shipped with their ghost buttons.',
       ),
       assert(
         meta == null || metaLabel != null,
         'PersonRow: reason content in meta needs metaLabel, for the same '
         'reason a trailing figure does — the row is one node and excludes '
         'what is under it.',
       ),
       assert(
         severity == null || severityLabel != null,
         'PersonRow: a severity bar is crimson, and the word beside it is '
         'what survives greyscale, deuteranopia, glare and a screen reader. '
         'SoftRow requires it; so does this.',
       );

  /// The full name. Wraps to two lines and middle-truncates only when a single
  /// line is structurally forced.
  final String? name;

  /// "Field agent", "Area manager". Already localised.
  final String? role;

  /// The outlet or territory. Joined to [role] with a middot only when both
  /// exist, so there is never a dangling separator.
  final String? outlet;

  /// A machine identifier, rendered in `mono.ident` on a third line **only**
  /// when there is no name. Never shown beside one.
  final String? identifier;

  /// The word that introduces [identifier] — "Reference", "id". Required
  /// alongside it, because a bare UUID on a line of its own is not a sentence.
  final String? identifierLabel;

  /// "Unknown agent". Becomes the title when there is no name and no role.
  final String? unknownLabel;

  /// A trailing word: "You", "Live", a state. Never a coloured badge.
  final String? trailingWord;

  /// A trailing widget, when the row needs a figure rather than a word.
  /// Ignored if [trailingWord] is set.
  final Widget? trailing;

  /// What [trailing] **says**, for the row's one semantics node.
  ///
  /// A `SoftRow` composes its label and excludes everything beneath it, so a
  /// rank, a points figure or a status chip dropped into [trailing] is painted
  /// and announced nowhere — the same hole that lost the worklists their row
  /// verbs. [trailingWord] never had the problem because it is a string the
  /// row can read; a widget is not, so the caller says what it means here.
  ///
  /// Two groups found this hole independently and closed it the same way. The
  /// assert on the constructor is the stricter of the two readings: a
  /// *decorative* trailing has nothing to announce, but it also has no reason
  /// to be a widget — [PersonRow] paints its own chevron from [onTap], so
  /// every `trailing` a caller actually passes carries a fact.
  final String? trailingLabel;

  /// Extra reason content beneath the role line — the evidence behind an
  /// accusation, the rules that fired, where a ruling stands.
  ///
  /// It composes *below* the identifier line rather than replacing it, so an
  /// unnamed person keeps their reference and their reason both.
  final Widget? meta;

  /// [meta]'s content in words, for the row's one semantics node.
  final String? metaLabel;

  /// The row's own verbs, beneath the text column and inset to it. They keep
  /// their own semantics nodes: a button dropped into [meta] paints,
  /// hit-tests and is announced nowhere.
  final Widget? actions;

  /// A severity bar down the leading edge. The lane is reserved whether or
  /// not one is painted, so a list of rows still reads as one column.
  final SoftRowSeverity? severity;

  /// The severity in words. Required with [severity].
  final String? severityLabel;

  /// Ink drops to ink-mute, the chevron goes, the row stops being tappable —
  /// and the caller passes the reason as [trailingWord] ("No longer active").
  final bool deactivated;

  final VoidCallback? onTap;

  /// The one legitimate use for a raw id: a deliberate gesture that copies it.
  final VoidCallback? onLongPress;

  final SoftRowDensity density;
  final SoftRowSeparator separator;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final hasName = name != null && name!.trim().isNotEmpty;
    final parts = <String>[
      if (role != null && role!.isNotEmpty) role!,
      if (outlet != null && outlet!.isNotEmpty) outlet!,
    ];

    // With a name, the name is the title and role · outlet is the reason line.
    // Without one, the role and outlet move up and the identifier — never
    // before now — appears on a third line.
    final title = hasName
        ? name!
        : (parts.isNotEmpty ? parts.join(' · ') : unknownLabel!);
    // Only a named row has a reason line: with no name the role and outlet
    // have already been promoted into the title and repeating them beneath
    // would be the same sentence twice.
    final subtitle = hasName && parts.isNotEmpty ? parts.join(' · ') : null;

    final showIdentifier =
        !hasName && identifier != null && identifierLabel != null;

    final Widget? identifierLine = showIdentifier
        ? _Identifier(label: identifierLabel!, value: identifier!)
        : null;

    return SoftRow(
      density: density,
      title: title,
      titleTruncation: SoftRowTruncation.middle,
      subtitle: subtitle,
      severity: severity ?? SoftRowSeverity.none,
      severityLabel: severityLabel,
      actions: actions,
      meta: identifierLine == null && meta == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ?identifierLine,
                if (identifierLine != null && meta != null)
                  const SizedBox(height: TiqSpace.s2),
                ?meta,
              ],
            ),
      leading: _InitialsTile(
        name: hasName ? name : null,
        deactivated: deactivated,
      ),
      trailing: _trailing(skin),
      enabled: !deactivated,
      onTap: deactivated ? null : onTap,
      onLongPress: onLongPress,
      separator: separator,
      semanticsLabel: <String?>[
        // Severity first: a queue read aloud has to say how bad before it
        // says whose, or the listener sorts the list twice.
        severityLabel,
        // The FULL name, whatever the row painted.
        hasName ? name : unknownLabel,
        if (parts.isNotEmpty) parts.join(', '),
        if (showIdentifier) '$identifierLabel ${_spell(identifier!)}',
        // Whichever trailing the row actually painted — the word, or what the
        // widget says. The word wins when both are set, because `_trailing`
        // paints the word and a reader must hear what is on the screen.
        trailingWord ?? (trailing == null ? null : trailingLabel),
        metaLabel,
      ].whereType<String>().join(', '),
    );
  }

  Widget? _trailing(TiqSkin skin) {
    if (trailingWord != null) {
      return Text(
        trailingWord!,
        textAlign: TextAlign.end,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: skin.text.label
            .copyWith(weight: FontWeight.w600)
            .style(color: deactivated ? skin.palette.inkMute : skin.palette.ink2),
      );
    }
    if (trailing != null) return trailing;
    return deactivated || onTap == null ? null : const SoftRowChevron();
  }

  /// An identifier is read character by character, because "a-b-c-1-2-3" is a
  /// reference somebody has to repeat down a phone line.
  static String _spell(String id) => id.split('').join(' ');
}

/// Initials on the `well`, in a radius-6 tile with a real edge. Never a photo,
/// never a silhouette icon.
class _InitialsTile extends StatelessWidget {
  const _InitialsTile({required this.name, required this.deactivated});

  final String? name;
  final bool deactivated;

  @override
  Widget build(BuildContext context) {
    final initials = _initialsOf(name);
    if (initials == null) {
      return RowMarkTile(
        mark: RowMark.barredRing,
        tone: deactivated ? RowMarkTone.muted : RowMarkTone.neutral,
      );
    }
    final skin = context.skin;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: skin.palette.well,
          borderRadius: BorderRadius.circular(skin.radii.chip),
          border: Border.all(
            color: skin.palette.edgeStructure,
            width: skin.depth.borderWidth,
          ),
        ),
        child: Center(
          child: Text(
            initials,
            maxLines: 1,
            style: skin.text.figureS.style(
              color: deactivated ? skin.palette.inkMute : skin.palette.ink2,
            ),
          ),
        ),
      ),
    );
  }

  /// Up to two initials from the first and last word. Null where the name is
  /// absent or carries no letters, which is what puts a barred ring in the
  /// tile instead of an empty box.
  static String? _initialsOf(String? name) {
    if (name == null) return null;
    final words = name
        .trim()
        .split(RegExp(r'[\s\-]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return null;
    final letters = <String>[
      words.first.substring(0, 1),
      if (words.length > 1) words.last.substring(0, 1),
    ].where((c) => RegExp(r'\p{L}', unicode: true).hasMatch(c)).toList();
    if (letters.isEmpty) return null;
    return letters.join().toUpperCase();
  }
}

class _Identifier extends StatelessWidget {
  const _Identifier({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: TiqSpace.s1,
      children: <Widget>[
        Text(label),
        Text(
          value,
          style: skin.text.monoIdent.style(color: skin.palette.ink3),
        ),
      ],
    );
  }
}
