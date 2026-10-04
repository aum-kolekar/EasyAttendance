import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/employee.dart';

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
  DateTime? _joiningDate;

  bool get _isEditing => widget.employee != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.employee?.name ?? '');
    _salaryController = TextEditingController(
      text: widget.employee != null
          ? widget.employee!.monthlySalary.toStringAsFixed(0)
          : '',
    );
    if (widget.employee?.joiningDate != null) {
      _joiningDate = DateTime.parse(widget.employee!.joiningDate!);
    } else if (!_isEditing) {
      _joiningDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Future<void> _pickJoiningDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joiningDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _joiningDate = picked);
    }
  }

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final salary = double.parse(_salaryController.text.trim());
    final joiningDateStr = _joiningDate != null ? _formatDate(_joiningDate!) : null;

    if (_isEditing) {
      final updated = widget.employee!.copyWith(
        name: name,
        monthlySalary: salary,
        joiningDate: joiningDateStr,
        clearJoiningDate: joiningDateStr == null,
      );
      await DatabaseHelper.instance.updateEmployee(updated);
    } else {
      final newEmployee = Employee(
        name: name,
        monthlySalary: salary,
        joiningDate: joiningDateStr,
      );
      await DatabaseHelper.instance.insertEmployee(newEmployee);
    }

    if (mounted) Navigator.pop(context);
  }

  // Note: deleting/archiving an employee is handled from the Employee
  // Detail screen (Advance/Bonus/Edit) now, not here - keeps there
  // being exactly one clear place to delete from.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Employee' : 'Add Employee',
          style: const TextStyle(fontSize: 20),
        ),
      ),
      body: SingleChildScrollView(
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
              const SizedBox(height: 24),
              const Text(
                'Joining Date',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'Days before this date are excluded from pay (not counted as absent)',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickJoiningDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _joiningDate != null ? _displayDate(_joiningDate!) : 'Not set',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Spacer(),
                      if (_joiningDate != null)
                        TextButton(
                          onPressed: () => setState(() => _joiningDate = null),
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                ),
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