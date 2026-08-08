import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/employee.dart';
import '../models/advance.dart';
import '../models/bonus.dart';

// Shows a popup form to record a salary advance for the given employee.
Future<void> showAddAdvanceDialog(BuildContext context, Employee employee) async {
  await _showAddTransactionDialog(
    context: context,
    employee: employee,
    title: 'Advance for ${employee.name}',
    amountHint: 'e.g. 2000',
    saveButtonColor: Colors.orange,
    onSave: (amount, dateStr, note) async {
      await DatabaseHelper.instance.insertAdvance(
        Advance(employeeId: employee.id!, amount: amount, date: dateStr, note: note),
      );
    },
    successMessage: (amount) => 'Advance of ₹${amount.toStringAsFixed(0)} recorded',
  );
}

// Shows a popup form to record a bonus for the given employee.
Future<void> showAddBonusDialog(BuildContext context, Employee employee) async {
  await _showAddTransactionDialog(
    context: context,
    employee: employee,
    title: 'Bonus for ${employee.name}',
    amountHint: 'e.g. 1000',
    saveButtonColor: Colors.green,
    onSave: (amount, dateStr, note) async {
      await DatabaseHelper.instance.insertBonus(
        Bonus(employeeId: employee.id!, amount: amount, date: dateStr, note: note),
      );
    },
    successMessage: (amount) => 'Bonus of ₹${amount.toStringAsFixed(0)} recorded',
  );
}

// Shared implementation - identical shape for both Advance and Bonus,
// only the destination table and labels differ.
Future<void> _showAddTransactionDialog({
  required BuildContext context,
  required Employee employee,
  required String title,
  required String amountHint,
  required Color saveButtonColor,
  required Future<void> Function(double amount, String dateStr, String? note) onSave,
  required String Function(double amount) successMessage,
}) async {
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  final formKey = GlobalKey<FormState>();

  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(title, style: const TextStyle(fontSize: 18)),
            // SingleChildScrollView is the key fix: without it, the dialog's
            // content can't shrink when the on-screen keyboard opens, which
            // was causing the "BOTTOM OVERFLOWED" error.
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Amount (₹)', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: amountHint,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter an amount';
                        }
                        final parsed = double.tryParse(value.trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a valid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Date', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 18),
                            const SizedBox(width: 8),
                            Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Note (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. festival bonus',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: saveButtonColor),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;

                  final amount = double.parse(amountController.text.trim());
                  final dateStr =
                      '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                  final note = noteController.text.trim().isEmpty ? null : noteController.text.trim();

                  await onSave(amount, dateStr, note);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(successMessage(amount))),
                    );
                  }
                },
                child: const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    },
  );
}