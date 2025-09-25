import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Employee model
class Employee {
  final String id;
  final String gmplEmpDept;
  final String gmplEmpDeptName;
  final String pfId;
  final String name;

  Employee({
    required this.id,
    required this.gmplEmpDept,
    required this.gmplEmpDeptName,
    required this.pfId,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gmpl_emp_dept': gmplEmpDept,
      'gmpl_emp_dept_name': gmplEmpDeptName,
      'pf_id': pfId,
      'name': name,
    };
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'].toString(),
      gmplEmpDept: map['gmpl_emp_dept'].toString(),
      gmplEmpDeptName: map['gmpl_emp_dept_name'].toString(),
      pfId: map['pf_id'].toString(),
      name: map['name'].toString(),
    );
  }
}

/// Shared DB provider (creates both tables)
class DbProvider {
  DbProvider._();
  static final DbProvider instance = DbProvider._();

  static const _dbName = "gmpl.db";
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Employees table
        await db.execute('''
          CREATE TABLE employees (
            id TEXT PRIMARY KEY,
            gmpl_emp_dept TEXT,
            gmpl_emp_dept_name TEXT,
            pf_id TEXT,
            name TEXT
          )
        ''');

        // Tiffin table
        await db.execute('''
          CREATE TABLE gmpl_emp_tiffin (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            gmpl_emp_record TEXT NOT NULL,
            gmpl_emp_dept TEXT NOT NULL,
            gmpl_emp_dept_name TEXT NOT NULL,
            pf_id TEXT NOT NULL,
            name TEXT NOT NULL,
            employee TEXT NOT NULL,
            scanned_on TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );

    return _db!;
  }
}

/// Employee table access
class EmployeeDb {
  EmployeeDb._();
  static final EmployeeDb instance = EmployeeDb._();
  static const _table = "employees";

  Future<Employee?> getEmployeeById(String id) async {
    final db = await DbProvider.instance.database;
    final res = await db.query(_table, where: "id = ?", whereArgs: [id]);
    if (res.isNotEmpty) {
      return Employee.fromMap(res.first);
    }
    return null;
  }

  Future<void> insertOrUpdate(Employee emp) async {
    final db = await DbProvider.instance.database;
    await db.insert(
      _table,
      emp.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Employee>> getAllEmployees() async {
    final db = await DbProvider.instance.database;
    final res = await db.query(_table, orderBy: "name ASC");
    return res.map((e) => Employee.fromMap(e)).toList();
  }

  Future<void> deleteEmployeesNotIn(List<String> ids) async {
    final db = await DbProvider.instance.database;
    if (ids.isEmpty) {
      await db.delete(_table);
    } else {
      final idsStr = ids.map((_) => '?').join(',');
      await db.delete(
        _table,
        where: 'id NOT IN ($idsStr)',
        whereArgs: ids,
      );
    }
  }
}
