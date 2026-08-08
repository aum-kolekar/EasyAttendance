import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../widgets/add_advance_dialog.dart';
import 'add_edit_employee_screen.dart';

class EmployeeDetailScreen extends StatelessWidget {
  final Employee employee;

  const EmployeeDetailScreen({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(employee.name, style: const TextStyle(fontSize: 20)),
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