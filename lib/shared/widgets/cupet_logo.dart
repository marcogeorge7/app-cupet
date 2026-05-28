import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';

/// Stacked CuPet brand mark — the cat app icon with the black wordmark logo
/// underneath. Use this for splash + onboarding heroes.
class CupetLogo extends StatelessWidget {
  const CupetLogo({
    super.key,
    this.size = 120,
    this.showWordmark = true,
  });

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.23),
          child: Image.asset(
            'assets/icon/icon.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
        if (showWordmark) ...[
          SizedBox(height: size * 0.16),
          Image.asset(
            'assets/images/cupet_wordmark.png',
            width: size * 1.83,
            fit: BoxFit.contain,
          ),
        ],
      ],
    );
  }
}

/// The image wordmark used by the login + splash screens, sized for app bars.
/// Use this so every screen shows the same `cupet_wordmark.png` brand mark.
class CupetWordmarkLogo extends StatelessWidget {
  const CupetWordmarkLogo({super.key, this.height = 28});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/cupet_wordmark.png',
      height: height,
      fit: BoxFit.contain,
    );
  }
}

/// `CuPet` rendered the way the brand deck draws it: alternating-case Barrio
/// type with a tiny `©` superscript. Tap-target friendly when scaled down for
/// app bars.
class CupetWordmark extends StatelessWidget {
  const CupetWordmark({
    super.key,
    this.fontSize = 48,
    this.color = CupetColors.ink,
    this.showCopyright = true,
  });

  final double fontSize;
  final Color color;
  final bool showCopyright;

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.barrio(
      fontSize: fontSize,
      color: color,
      letterSpacing: -0.5,
      height: 1,
    );
    final small = base.copyWith(
      fontSize: fontSize * 0.62,
      color: color.withValues(alpha: 0.85),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showCopyright)
          Padding(
            padding: EdgeInsets.only(top: fontSize * 0.05, right: fontSize * 0.06),
            child: Text(
              '©',
              style: GoogleFonts.barrio(
                fontSize: fontSize * 0.35,
                color: color.withValues(alpha: 0.7),
                height: 1,
              ),
            ),
          ),
        Text('C', style: base),
        Text('u', style: small),
        Text('P', style: base),
        Text('e', style: small),
        Text('t', style: base),
      ],
    );
  }
}
