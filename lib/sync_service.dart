// sync_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'employee_db.dart';
import 'tiffin_db.dart';

class SyncService {
  // 🔹 Existing employee sync (unchanged)
  static Future<String> syncEmployees() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString("user_id") ?? "";
      final mob = prefs.getString("mob") ?? "";
      final ip = prefs.getString("ip") ?? "localhost";
      final baseUrl =
         // "http://$ip/gmpl/native_app/tiffin_emp_sync.php?subject=emp&action=init";
          "https://$ip/gmpl_tiffin/native_app/tiffin_emp_sync.php?subject=emp&action=init";
      final response = await http.post(
        Uri.parse(baseUrl),
        body: {"user_id": userId, "mob": mob},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["status"] == true && data["ms_emp"] != null) {
          final List employees = data["ms_emp"];
          final List<String> apiIds = [];

          for (final e in employees) {
            final emp = Employee(
              id: e["id"].toString(),
              gmplEmpDept: e["gmpl_emp_dept"].toString(),
              gmplEmpDeptName: e["gmpl_emp_dept_name"].toString(),
              pfId: e["pf_id"].toString(),
              name: e["name"].toString(),
            );

            apiIds.add(emp.id);
            await EmployeeDb.instance.insertOrUpdate(emp);
          }

          await EmployeeDb.instance.deleteEmployeesNotIn(apiIds);

          return "Employee sync successful: ${employees.length} records.";
        } else {
          return "No employees found or status=false.";
        }
      } else {
        return "HTTP error: ${response.statusCode}";
      }
    } catch (e) {
      return "Sync failed: $e";
    }
  }

  // 🔹 NEW: Attendance sync from tiffin_db
  static Future<String> syncAttendance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ip = prefs.getString("ip") ?? "localhost";
      final userId = prefs.getString("user_id") ?? ""; // 👈 use pref value
      final baseUrl =
       //   "http://$ip/gmpl/native_app/tiffin_save.php?subject=tiffin&action=save";
          "https://$ip/gmpl_tiffin/native_app/tiffin_save.php?subject=tiffin&action=save";
      // Get unsynced records
      final pending = await TiffinDb.instance.getUnsynced();
      if (pending.isEmpty) {
        return "No pending attendance records to sync.";
      }

      // Build payload
      final List<Map<String, dynamic>> payload = pending.map((rec) {
        return {
          "id": rec.id ?? 0,
          "gmpl_emp_record": rec.gmplEmpRecord,
          "gmpl_emp_dept": rec.gmplEmpDept,
          "gmpl_emp_dept_name": rec.gmplEmpDeptName,
          "pf_id": rec.pfId,
          "name": rec.name,
          // 👇 employee always from prefs, not local record
          "employee": userId,
          // ✅ Format DateTime → MySQL DATETIME
          "scanned_on":
          "${rec.scannedOn.year}-${rec.scannedOn.month.toString().padLeft(2, '0')}-${rec.scannedOn.day.toString().padLeft(2, '0')} "
              "${rec.scannedOn.hour.toString().padLeft(2, '0')}:${rec.scannedOn.minute.toString().padLeft(2, '0')}:${rec.scannedOn.second.toString().padLeft(2, '0')}",
        };
      }).toList();

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["status"] == true) {
          // ✅ mark all synced
          final ids = pending.map((e) => e.id!).toList();
          await TiffinDb.instance.markSynced(ids);

          return "Attendance sync successful: ${pending.length} records.";
        } else {
          return "Server error: ${data["message"]}";
        }
      } else {
        return "HTTP error: ${response.statusCode}";
      }
    } catch (e) {
      return "Attendance sync failed: $e";
    }
  }
}
