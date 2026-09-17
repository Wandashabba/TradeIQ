import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/glass.dart';
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

/// The live web pages an answer cited, as numbered footnotes under it.
///
/// Deliberately quiet: the answer is the point, and these say where its
/// outside facts came from. Every string is drawn as plain text — a title or
/// snippet off the open web is never parsed as markdown.
class WebSources extends StatelessWidget {
  const WebSources({
    super.key,
    required this.sources,
    this.launcher = openWebSource,
  });

  final List<WebSource> sources;
  final WebSourceLauncher launcher;

  static const label = 'Web sources';

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final glass = colors.glass;
    final lumen = context.lumen;
    final muted = glass ? lumen.inkMuted : colors.ink3;
    final ink = glass ? lumen.ink : colors.ink1;
    final accent = glass ? lumen.accentInk : colors.brand;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            label,
            key: const ValueKey('web-sources-label'),
            style: LumenGlass.figure(
              size: 12,
              color: muted,
              weight: FontWeight.w500,
            ).copyWith(height: 1.2),
          ),
        ),
        const SizedBox(height: 5),
        for (var i = 0; i < sources.length; i++)
          _SourceRow(
            key: ValueKey('web-source-$i'),
            index: i + 1,
            source: sources[i],
            ink: ink,
            muted: muted,
            accent: accent,
            onTap: () {
              final url = sources[i].url;
              if (WebSource.isWebUri(url)) launcher(url);
            },
          ),
      ],
    );

    const padding = EdgeInsets.fromLTRB(8, 9, 8, 6);
    if (glass) {
      return GlassPane(
        key: const ValueKey('web-sources'),
        kind: GlassKind.tile,
        blur: false,
        shadow: false,
        radius: LumenGlass.radiusControl,
        padding: padding,
        child: body,
      );
    }
    return Container(
      key: const ValueKey('web-sources'),
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(colors.radiusCard),
      ),
      child: body,
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    super.key,
    required this.index,
    required this.source,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.onTap,
  });

  final int index;
  final WebSource source;
  final Color ink;
  final Color muted;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$index',
              style: LumenGlass.figure(
                size: 11,
                color: accent,
                weight: FontWeight.w600,
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              source.domain,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              source.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, height: 1.3, color: muted),
            ),
          ),
          if (source.pageAge != null) ...[
            const SizedBox(width: 8),
            Text(
              source.pageAge!,
              maxLines: 1,
              style: LumenGlass.figure(
                size: 10.5,
                color: muted,
                weight: FontWeight.w400,
              ),
            ),
          ],
          const SizedBox(width: 6),
          Icon(Icons.north_east, size: 12, color: muted),
        ],
      ),
    );

    Widget tappable = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LumenGlass.radiusChip),
        child: row,
      ),
    );

    // The snippet is a preview, not content: a hover/long-press tooltip, in
    // plain text, so it costs the transcript no height.
    final snippet = source.snippet;
    if (snippet != null) {
      tappable = Tooltip(
        message: snippet,
        excludeFromSemantics: true,
        waitDuration: const Duration(milliseconds: 500),
        child: tappable,
      );
    }

    return Semantics(
      button: true,
      link: true,
      label: 'Web source: ${source.title}, ${source.domain}, opens in browser',
      excludeSemantics: true,
      onTap: onTap,
      child: tappable,
    );
  }
}
