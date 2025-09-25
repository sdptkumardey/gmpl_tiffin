import 'package:sqflite/sqflite.dart';
import 'employee_db.dart'; // reuse DbProvider

/// Tiffin record model
class TiffinRecord {
  final int? id;
  final String gmplEmpRecord;
  final String gmplEmpDept;
  final String gmplEmpDeptName;
  final String pfId;
  final String name;
  final String employee;
  final DateTime scannedOn;
  final bool synced;

  TiffinRecord({
    this.id,
    required this.gmplEmpRecord,
    required this.gmplEmpDept,
    required this.gmplEmpDeptName,
    required this.pfId,
    required this.name,
    required this.employee,
    required this.scannedOn,
    this.synced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "gmpl_emp_record": gmplEmpRecord,
      "gmpl_emp_dept": gmplEmpDept,
      "gmpl_emp_dept_name": gmplEmpDeptName,
      "pf_id": pfId,
      "name": name,
      "employee": employee,
      "scanned_on": scannedOn.toIso8601String(),
      "synced": synced ? 1 : 0,
    };
  }

  factory TiffinRecord.fromMap(Map<String, dynamic> map) {
    return TiffinRecord(
      id: map["id"] as int?,
      gmplEmpRecord: map["gmpl_emp_record"].toString(),
      gmplEmpDept: map["gmpl_emp_dept"].toString(),
      gmplEmpDeptName: map["gmpl_emp_dept_name"].toString(),
      pfId: map["pf_id"].toString(),
      name: map["name"].toString(),
      employee: map["employee"].toString(),
      scannedOn: DateTime.parse(map["scanned_on"]),
      synced: (map["synced"] as int) == 1,
    );
  }
}

/// Tiffin table access
class TiffinDb {
  TiffinDb._();
  static final TiffinDb instance = TiffinDb._();
  static const _table = "gmpl_emp_tiffin";

  Future<int> insertScan(TiffinRecord rec) async {
    final db = await DbProvider.instance.database;
    return db.insert(_table, rec.toMap());
  }

  Future<List<TiffinRecord>> getUnsynced() async {
    final db = await DbProvider.instance.database;
    final rows = await db.query(_table, where: "synced = 0");
    return rows.map((e) => TiffinRecord.fromMap(e)).toList();
  }

  Future<void> markSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await DbProvider.instance.database;
    final batch = db.batch();
    for (final id in ids) {
      batch.update(_table, {"synced": 1}, where: "id = ?", whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  Future<int> countAll() async {
    final db = await DbProvider.instance.database;
    final r = await db.rawQuery("SELECT COUNT(*) as c FROM $_table");
    return (r.first["c"] as int?) ?? 0;
  }

  /// ✅ Get last scan record for an employee
  Future<TiffinRecord?> getLastScanForEmployee(String empId) async {
    final db = await DbProvider.instance.database;
    final maps = await db.query(
      _table,
      where: 'gmpl_emp_record = ?',
      whereArgs: [empId],
      orderBy: 'scanned_on DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return TiffinRecord.fromMap(maps.first);
    }
    return null;
  }
}
