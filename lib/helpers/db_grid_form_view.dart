// lib/helpers/db_grid_form_view.dart
import 'package:flutter/material.dart';
import 'package:una_social_app/helpers/db_grid.dart';
import 'package:una_social_app/helpers/logger_helper.dart'; // For DBGridControl and UIMode

class DBGridFormView extends StatelessWidget {
  final Map<String, dynamic> formData;
  final DBGridControl dbGridControl;
  final List<String> primaryKeyColumns; // Columns that are primary keys

  const DBGridFormView({
    super.key,
    required this.formData,
    required this.dbGridControl,
    required this.primaryKeyColumns,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // Sort keys to ensure a consistent order, PKs first if possible
    List<String> sortedKeys = formData.keys.toList();
    sortedKeys.sort((a, b) {
      bool aIsPk = primaryKeyColumns.contains(a);
      bool bIsPk = primaryKeyColumns.contains(b);
      if (aIsPk && !bIsPk) return -1;
      if (!aIsPk && bIsPk) return 1;
      return a.compareTo(b); // Alphabetical for others
    });

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600, // Max width for the form
          minHeight: MediaQuery.of(context).size.height * 0.5, // Min height
        ),
        child: Card(
          margin: const EdgeInsets.all(16.0),
          elevation: 4.0,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min, // So the card wraps content
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Dettaglio Record", // Generic title
                  style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24.0),
                Flexible(
                  // Allows the list to scroll if content overflows
                  child: ListView.separated(
                    shrinkWrap: true, // Important for Column + ListView
                    itemCount: sortedKeys.length,
                    itemBuilder: (context, index) {
                      final key = sortedKeys[index];
                      final value = formData[key];
                      final bool isPrimaryKey = primaryKeyColumns.contains(key);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: TextFormField(
                          initialValue: value?.toString() ?? '',
                          readOnly: isPrimaryKey, // PKs are not editable
                          decoration: InputDecoration(
                            labelText: key.replaceAll('_', ' ').toUpperCase(),
                            labelStyle: TextStyle(
                              color: isPrimaryKey ? Colors.red : colorScheme.onSurfaceVariant,
                              fontWeight: isPrimaryKey ? FontWeight.bold : FontWeight.normal,
                            ),
                            filled: isPrimaryKey,
                            // Updated: withAlpha instead of withOpacity
                            fillColor: isPrimaryKey ? Colors.yellow.withAlpha((0.2 * 255).round()) : null,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                          ),
                          style: TextStyle(
                            color: isPrimaryKey ? Colors.red : colorScheme.onSurface,
                            // Updated: withAlpha instead of withOpacity
                            backgroundColor: isPrimaryKey ? Colors.yellow.withAlpha((0.1 * 255).round()) : Colors.transparent,
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (context, index) => const SizedBox(height: 12.0),
                  ),
                ),
                const SizedBox(height: 16.0),
                const Divider(),
                const SizedBox(height: 16.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      tooltip: "Record Precedente",
                      onPressed: dbGridControl.canGoToPreviousRecordInForm() ? () => dbGridControl.goToPreviousRecordInForm() : null, // Disable if cannot go back
                    ),
                    Text("Record X di Y"), // Placeholder for current record number
                    IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        tooltip: "Record Successivo",
                        onPressed: () {
                          bool yesWeCan = dbGridControl.canGoToNextRecordInForm();
                          logInfo("Record Successivo: $yesWeCan");
                          if (yesWeCan) {
                            dbGridControl.goToNextRecordInForm();
                          }
                        }),
                  ],
                ),
                const SizedBox(height: 20.0),
                ElevatedButton(
                  onPressed: () {
                    dbGridControl.toggleUIModePublic();
                  },
                  child: const Text("Torna alla Griglia"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
