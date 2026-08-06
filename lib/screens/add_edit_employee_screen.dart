import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/employee.dart';

// This ONE screen handles both "Add new employee" and "Edit existing employee".
// If `employee` is null -> Add mode. If it's provided -> Edit mode.
class AddEditEmployeeScreen extends StatefulWidget {
  final Employee? employee;

  const AddEditEmployeeScreen({super.key, this.employee});

  @override
  State<AddEditEmployeeScreen> createState() => _AddEditEmployeeScreenState();
}

class _AddEditEmployeeScreenState extends State<AddEditEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _salaryController;

  bool get _isEditing => widget.employee != null;

  @override
  void initState() {
    super.initState();
    // Pre-fill fields if we're editing an existing employee
    _nameController = TextEditingController(text: widget.employee?.name ?? '');
    _salaryController = TextEditingController(
      text: widget.employee != null
          ? widget.employee!.monthlySalary.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _saveEmployee() async {
    // Validates the form fields (see validator functions below)
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final salary = double.parse(_salaryController.text.trim());

    if (_isEditing) {
      final updated = widget.employee!.copyWith(
        name: name,
        monthlySalary: salary,
      );
      await DatabaseHelper.instance.updateEmployee(updated);
    } else {
      final newEmployee = Employee(name: name, monthlySalary: salary);
      await DatabaseHelper.instance.insertEmployee(newEmployee);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteEmployee() async {
    // Confirm before deleting - avoids accidental taps
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee?'),
        content: Text('Remove ${widget.employee!.name}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteEmployee(widget.employee!.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Employee' : 'Add Employee',
          style: const TextStyle(fontSize: 20),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteEmployee,
              tooltip: 'Delete Employee',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Employee Name',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: 'e.g. Ramesh Kumar',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the employee name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Monthly Salary (₹)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _salaryController,
                style: const TextStyle(fontSize: 18),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: 'e.g. 15000',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the monthly salary';
                  }
                  final parsed = double.tryParse(value.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a valid salary amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveEmployee,
                  child: Text(
                    _isEditing ? 'Save Changes' : 'Add Employee',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}