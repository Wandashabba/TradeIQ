import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/tiq_colors.dart';
import 'glass.dart';
import 'lumen_kit.dart';
import '../theme/lumen_palette.dart';

/// The page shell for screens pushed on top of the console — the create and
/// edit forms, the territory map, a beat plan's detail — which have no nav of
/// their own.
///
/// Glass (light): the same lit ground and translucent window bar as
/// [ManagerScaffold], with a glass back chip in place of the stock arrow.
/// Dark: exactly the plain [Scaffold] + [AppBar] these screens always had.
class GlassPageScaffold extends StatelessWidget {
  const GlassPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.backgroundColor,
  });

  final Widget title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  /// Dark only — glass always paints the ground.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (!colors.glass) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(title: title, actions: actions),
        floatingActionButton: floatingActionButton,
        body: body,
      );
    }

    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    return Scaffold(
      backgroundColor: colors.plane,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: title,
        actions: actions,
        automaticallyImplyLeading: false,
        leading: canPop
            ? GlassBackChip(onTap: () => Navigator.of(context).maybePop())
            : null,
        backgroundColor: context.lumen.white(0x6B),
        surfaceTintColor: Colors.transparent,
        shape: Border(bottom: BorderSide(color: context.lumen.white(0xCC))),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: const SizedBox.expand(),
          ),
        ),
      ),
      floatingActionButton: floatingActionButton,
      body: LitGround(
        layout: GroundLayout.console,
        child: Builder(
          // The ground runs under the glass bar; the content starts below it,
          // and no scroll view applies that inset twice.
          builder: (context) => Padding(
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}
