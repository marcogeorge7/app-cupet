import 'package:flutter/material.dart';

import 'germeen.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.illustration,
    this.mood = GermeenMood.sleepy,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  /// Overrides the default vector [Germeen] hero — e.g. the brand logo mascot.
  final Widget? illustration;
  final GermeenMood mood;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            illustration ?? Germeen(size: 140, mood: mood),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
