// home_page.dart
import 'package:flutter/material.dart';
import 'package:gmpl_tiffin/scan_attendance_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sync_service.dart';
import 'employee_db.dart';
import 'tiffin_db.dart';
import 'login_screen.dart'; // 👈 import your login page

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String userName = "";
  bool isSyncing = false;
  int employeeCount = 0;
  int pendingAttendance = 0;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadEmployeeCount();
    _loadPendingAttendance();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString("name") ?? "User";
    });
  }

  Future<void> _loadEmployeeCount() async {
    final list = await EmployeeDb.instance.getAllEmployees();
    setState(() {
      employeeCount = list.length;
    });
  }

  Future<void> _loadPendingAttendance() async {
    final unsynced = await TiffinDb.instance.getUnsynced();
    setState(() {
      pendingAttendance = unsynced.length;
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // clear all saved keys

    if (!mounted) return;

    // Navigate to login page and remove all previous routes
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required List<Color> gradientColors,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors.last.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 20),
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70),
            const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _syncEmployees() async {
    setState(() => isSyncing = true);
    final result = await SyncService.syncEmployees();
    await _loadEmployeeCount();
    if (!mounted) return;
    setState(() => isSyncing = false);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Sync Complete"),
        content: Text("$result\n\nTotal Employees: $employeeCount"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _syncAttendance() async {
    setState(() => isSyncing = true);
    final result = await SyncService.syncAttendance();
    await _loadPendingAttendance();
    if (!mounted) return;
    setState(() => isSyncing = false);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Sync Attendance"),
        content: Text(result),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Welcome, $userName",
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF16038b),
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _logout,
              tooltip: "Logout",
            ),
          ],
        ),
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFc5bcfb), Color(0xFFeeecfb)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: isSyncing
              ? const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  "Syncing...",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
              : Column(
            children: [
              Expanded(
                child: _buildMenuButton(
                  icon: Icons.qr_code_scanner_rounded,
                  label: "Scan Attendance",
                  gradientColors: [Colors.blue, Colors.blueAccent],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ScanAttendancePage()),
                    ).then((_) => _loadPendingAttendance());
                  },
                ),
              ),
              Expanded(
                child: _buildMenuButton(
                  icon: Icons.sync_rounded,
                  label: "Sync Attendance ($pendingAttendance)",
                  gradientColors: [Colors.teal, Colors.green],
                  onTap: _syncAttendance,
                ),
              ),
              Expanded(
                child: _buildMenuButton(
                  icon: Icons.people_alt_rounded,
                  label: "Sync Employee ($employeeCount)",
                  gradientColors: [Colors.deepPurple, Colors.purple],
                  onTap: _syncEmployees,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
