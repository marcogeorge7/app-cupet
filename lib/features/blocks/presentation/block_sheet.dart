import 'package:flutter/material.dart';

import '../../../core/di/injector.dart';
import '../data/block_remote_data_source.dart';

/// Confirmation sheet for blocking a user. On success it runs [onBlocked]
/// (so the caller can drop the user from its list/deck instantly) and shows a
/// confirmation SnackBar. The backend also files a moderation report so the
/// team is notified of the inappropriate content.
Future<void> showBlockSheet(
  BuildContext context, {
  required int userId,
  required String name,
  VoidCallback? onBlocked,
}) async {
  final reasonCtrl = TextEditingController();
  // Resolve the app-level messenger now so the SnackBar still shows even if the
  // caller (e.g. the chat page) pops itself inside onBlocked.
  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      var submitting = false;
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Block $name?',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  '$name will be removed from your matches and discovery and '
                  "won't be able to message you. Our team is notified to review "
                  'the report.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: submitting
                      ? null
                      : () async {
                          setState(() => submitting = true);
                          try {
                            await getIt<BlockRemoteDataSource>().blockUser(
                              userId: userId,
                              reason: reasonCtrl.text.trim().isEmpty
                                  ? null
                                  : reasonCtrl.text.trim(),
                            );
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop(true);
                            }
                          } catch (_) {
                            if (sheetContext.mounted) {
                              setState(() => submitting = false);
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Could not block. Please try again.'),
                                ),
                              );
                            }
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Block $name'),
                ),
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(sheetContext).pop(false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  reasonCtrl.dispose();

  if (confirmed == true) {
    onBlocked?.call();
    messenger.showSnackBar(
      SnackBar(content: Text('You blocked $name.')),
    );
  }
}
