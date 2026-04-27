import 'package:flutter/material.dart';

import '../../app/theme.dart';

class CupetLogo extends StatelessWidget {
  const CupetLogo({super.key, this.size = 80});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: size,
          width: size,
          decoration: const BoxDecoration(
            color: CupetColors.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '🐾',
            style: TextStyle(fontSize: size * 0.55),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'CuPet',
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ],
    );
  }
}
