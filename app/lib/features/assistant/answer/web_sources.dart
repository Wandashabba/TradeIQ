import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/figure_slot.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/mark/tiq_mark.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state/toast.dart';
import '../../../l10n/l10n.dart';
import '../data/assistant_events.dart';

/// Opens a cited page. Injected so a widget test can see the tapped [Uri]
/// without a platform channel.
typedef WebSourceLauncher = Future<bool> Function(Uri url);

/// The production launcher: the platform's own browser, never an in-app web
/// view — a cited page is someone else's site and should look like it.
///
/// The scheme is checked again here, at the last moment before a browser is
/// involved, whatever parsed it earlier.
Future<bool> openWebSource(Uri url) async {
  if (!WebSource.isWebUri(url)) return false;
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {
    // No browser, or a platform that refused. Nothing the manager can act on.
    return false;
  }
}

/// WHERE THE ANSWER'S OUTSIDE FACTS CAME FROM.
///
/// A [SectionRule] and a list of rows — the same grammar as the callout, so
/// this surface has exactly two section markers and they look like each other.
/// Sentence case, `title.m`, knocked out of the rule: unify §1.17 retires the
/// uppercase eyebrow as a screen-level marker, and "SOURCES" was one.
///
/// Every string is drawn as plain text: a title off the open web is never
/// parsed as markdown.
///
/// **Amber: none.** The old build tinted the index in the accent. A footnote
/// number is not a light source.
class WebSources extends StatefulWidget {
  const WebSources({
    super.key,
    required this.sources,
    this.launcher = openWebSource,
    this.searched = false,
  });

  final List<WebSource> sources;
  final WebSourceLauncher launcher;

  /// Whether a web search actually ran. A turn that searched and cited
  /// nothing says so; a turn that never searched shows no header at all — an
  /// empty "Sources" heading is never rendered.
  final bool searched;

  /// Rows shown before the expander.
  static const int shownRows = 4;

  @override
  State<WebSources> createState() => _WebSourcesState();
}

class _WebSourcesState extends State<WebSources> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    if (widget.sources.isEmpty && !widget.searched) {
      return const SizedBox.shrink();
    }

    final shown = _all
        ? widget.sources
        : widget.sources.take(WebSources.shownRows).toList();
    final hidden = widget.sources.length - shown.length;

    return Semantics(
      container: true,
      label: l10n.askSourcesGroup(widget.sources.length),
      child: Column(
        key: const ValueKey<String>('web-sources'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SectionRule(
            l10n.askSources,
            count: widget.sources.isEmpty ? null : widget.sources.length,
            // A search that found nothing usable is a fact about the search,
            // not an empty state — the rule stays and says so.
            emptyLine: widget.sources.isEmpty
                ? l10n.askSourcesNothingUsable
                : null,
          ),
          if (shown.isNotEmpty) SizedBox(height: skin.space.intraBlock),
          for (var i = 0; i < shown.length; i++)
            SourceRow(
              key: ValueKey<String>('web-source-$i'),
              index: i + 1,
              source: shown[i],
              launcher: widget.launcher,
              last: i == shown.length - 1 && hidden == 0,
            ),
          if (hidden > 0)
            SoftRow(
              key: const ValueKey<String>('web-sources-show-all'),
              density: SoftRowDensity.compact,
              title: l10n.askShowAllSources(widget.sources.length),
              separator: SoftRowSeparator.none,
              onTap: () => setState(() => _all = true),
            ),
        ],
      ),
    );
  }
}

/// ONE CITED PAGE, readable as a row and honest that it leaves the app.
///
/// Two lines, not one — a one-line row is where long titles and Afrikaans
/// both die. The index is a figure and goes through `FigureSlot`; the domain
/// middle-truncates before the title does, because the host is the half you
/// cannot guess.
class SourceRow extends StatefulWidget {
  const SourceRow({
    super.key,
    required this.index,
    required this.source,
    required this.launcher,
    this.last = false,
  });

  final int index;
  final WebSource source;
  final WebSourceLauncher launcher;
  final bool last;

  @override
  State<SourceRow> createState() => _SourceRowState();
}

class _SourceRowState extends State<SourceRow> {
  static const int _previewLength = 160;

  /// The platform refused the launch. The row stays — it is still provenance
  /// — and says what to do instead.
  bool _unreachable = false;

  Future<void> _open() async {
    final url = widget.source.url;
    if (!WebSource.isWebUri(url)) {
      setState(() => _unreachable = true);
      return;
    }
    final ok = await widget.launcher(url);
    if (!ok && mounted) setState(() => _unreachable = true);
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.source.url.toString()));
    if (!mounted) return;
    final l10n = context.l10n;
    // The search result's preview rides on the same long-press, in plain
    // text: a preview costs the transcript no height, and it is never parsed
    // as markdown. Clipped, because a toast is a report and not a page.
    final snippet = widget.source.snippet?.trim();
    showTorchToast(
      context,
      message: snippet == null || snippet.isEmpty
          ? l10n.askSourceCopied
          : l10n.askSourceCopiedPreview(
              snippet.length <= _previewLength
                  ? snippet
                  : '${snippet.substring(0, _previewLength).trimRight()}…',
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final p = skin.palette;
    final source = widget.source;

    final meta = <String>[
      if (source.pageAge != null) source.pageAge!,
      if (_unreachable)
        l10n.askSourceUnreachable
      else
        l10n.askSourceOpensInBrowser,
    ].join(' · ');

    return SoftRow(
      density: SoftRowDensity.tall,
      leading: Padding(
        padding: const EdgeInsets.only(top: TiqSpace.s1),
        child: FigureSlot(
          value: widget.index,
          role: skin.text.monoIdent,
          color: p.ink3,
        ),
      ),
      title: source.domain,
      // The host middle-truncates; the title below it wraps and the row
      // grows. A status word is never truncated before a name is.
      titleTruncation: SoftRowTruncation.middle,
      subtitle: source.title,
      meta: Text(meta, style: skin.text.meta.style(color: p.ink3)),
      trailing: Icon(
        _unreachable ? Icons.link_off : Icons.north_east,
        size: MarkScale.glyph(context, 14),
        color: p.ink3,
      ),
      separator: widget.last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: l10n.askSourceSemantic(
        widget.index,
        source.domain,
        source.title,
      ),
      onTap: _open,
      onLongPress: _copy,
    );
  }
}
