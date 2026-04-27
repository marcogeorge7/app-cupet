import 'package:flutter/material.dart';

import '../../../core/di/injector.dart';
import '../data/report_remote_data_source.dart';

const _reasons = [
  'Inappropriate photo',
  'Spam or fake profile',
  'Harassment or abuse',
  'Other',
];

Future<void> showReportSheet(BuildContext context, int petId) async {
  String? selectedReason;
  final detailsCtrl = TextEditingController();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Report this pet',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                ..._reasons.map(
                  (reason) => RadioListTile<String>(
                    title: Text(reason),
                    value: reason,
                    groupValue: selectedReason,
                    onChanged: (v) => setState(() => selectedReason = v),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: detailsCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Details (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: selectedReason == null
                      ? null
                      : () async {
                          await getIt<ReportRemoteDataSource>().reportPet(
                            petId: petId,
                            reason: selectedReason!,
                            details: detailsCtrl.text.trim().isEmpty
                                ? null
                                : detailsCtrl.text.trim(),
                          );
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                  child: const Text('Send report'),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}
