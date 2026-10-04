import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/employee.dart';
import '../widgets/add_advance_dialog.dart';
import 'add_edit_employee_screen.dart';

class EmployeeDetailScreen extends StatelessWidget {
  final Employee employee;

  const EmployeeDetailScreen({super.key, required this.employee});

  // Archives the employee (soft delete) after a simple Yes/No
  // confirmation. All their attendance/advance/bonus history stays
  // intact - they just move to Archives, where they can be restored
  // or, if truly needed, permanently deleted later.
  Future<void> _deleteEmployee(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Employee?'),
        content: Text('Are you sure you want to delete ${employee.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.archiveEmployee(employee.id!);
      if (context.mounted) {
        // A dialog with an explicit OK button (instead of a snackbar)
        // makes sure this is actually read, not just glimpsed and
        // swiped away.
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.archive_outlined, color: Colors.grey.shade700, size: 22),
                const SizedBox(width: 8),
                const Text('Employee Deleted'),
              ],
            ),
            content: Text(
              '${employee.name} has been deleted. You can still access '
              'them from Archives for future reference.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (context.mounted) Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(employee.name, style: const TextStyle(fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete Employee',
            onPressed: () => _deleteEmployee(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Monthly Salary: ₹${employee.monthlySalary.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            _actionButton(
              context,
              icon: Icons.remove_circle_outline,
              label: 'Add Advance',
              subtitle: 'Deducted from salary',
              color: Colors.orange,
              onTap: () => showAddAdvanceDialog(context, employee),
            ),
            const SizedBox(height: 16),
            _actionButton(
              context,
              icon: Icons.add_circle_outline,
              label: 'Add Bonus',
              subtitle: 'Added to salary',
              color: Colors.green,
              onTap: () => showAddBonusDialog(context, employee),
            ),
            const SizedBox(height: 16),
            _actionButton(
              context,
              icon: Icons.edit,
              label: 'Edit Details',
              subtitle: 'Name or monthly salary',
              color: Colors.blue,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddEditEmployeeScreen(employee: employee)),
                );
                if (context.mounted) Navigator.pop(context); // refresh the list behind us
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 76,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          elevation: 0,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 30, color: color),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: color.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}