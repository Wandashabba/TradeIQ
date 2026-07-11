import 'package:flutter/material.dart';

/// The supplied TradeIQ monogram used on public app screens.
class TradeIqLogo extends StatelessWidget {
  const TradeIqLogo({super.key, this.size = 40});

  static const assetPath = 'assets/images/tradeiq-ti-monogram.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.1,
      height: size,
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        semanticLabel: 'TradeIQ',
      ),
    );
  }
}
