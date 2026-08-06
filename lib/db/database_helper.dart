import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/employee.dart';

// This class is a "singleton" - only ONE instance of it exists for the
// whole app. That's the standard pattern for a database connection.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  // Private constructor - nobody outside this class can create a new one.
  DatabaseHelper._internal();

  // Gets the database, creating/opening it the first time it's needed.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // getDatabasesPath() finds the correct local storage folder
    // on the device automatically - no manual path config needed.
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'attendance_app.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // Runs once, the very first time the app is installed - creates our table.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE employees(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        monthlySalary REAL NOT NULL
      )
    ''');
  }

  // --- CRUD operations ---

  // CREATE: add a new employee, returns the new employee's id
  Future<int> insertEmployee(Employee employee) async {
    final db = await database;
    return await db.insert('employees', employee.toMap()..remove('id'));
  }

  // READ: get all employees, sorted alphabetically by name
  Future<List<Employee>> getAllEmployees() async {
    final db = await database;
    final maps = await db.query('employees', orderBy: 'name ASC');
    return maps.map((map) => Employee.fromMap(map)).toList();
  }

  // READ: get a single employee by id (useful later for edit screens)
  Future<Employee?> getEmployee(int id) async {
    final db = await database;
    final maps = await db.query('employees', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Employee.fromMap(maps.first);
  }

  // UPDATE: save changes to an existing employee (e.g. new salary)
  Future<int> updateEmployee(Employee employee) async {
    final db = await database;
    return await db.update(
      'employees',
      employee.toMap(),
      where: 'id = ?',
      whereArgs: [employee.id],
    );
  }

  // DELETE: remove an employee
  Future<int> deleteEmployee(int id) async {
    final db = await database;
    return await db.delete('employees', where: 'id = ?', whereArgs: [id]);
  }
}