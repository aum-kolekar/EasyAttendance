import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/employee.dart';
import 'add_edit_employee_screen.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  List<Employee> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  // Fetches the current employee list from the database and refreshes the UI
  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    final employees = await DatabaseHelper.instance.getAllEmployees();
    setState(() {
      _employees = employees;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees', style: TextStyle(fontSize: 22)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _employees.isEmpty
              ? const Center(
                  child: Text(
                    'No employees yet.\nTap + to add one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _employees.length,
                  itemBuilder: (context, index) {
                    final employee = _employees[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: const CircleAvatar(
                          radius: 24,
                          child: Icon(Icons.person, size: 28),
                        ),
                        title: Text(
                          employee.name,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Monthly Salary: ₹${employee.monthlySalary.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 15),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          // Tapping an employee opens the edit screen
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AddEditEmployeeScreen(employee: employee),
                            ),
                          );
                          _loadEmployees(); // refresh list after returning
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Opens the Add screen (no employee passed = "add" mode)
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditEmployeeScreen()),
          );
          _loadEmployees(); // refresh list after returning
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Employee'),
      ),
    );
  }
}