// main.dart
// Flutter QR Attendance Kiosk Demo
// - Front camera stays on
// - Hands-free QR detection (no taps)
// - Brief success overlay, then auto-returns to camera
// - Offline-first: stores scans in local SQLite for later sync
//
// Packages:
//   mobile_scanner: ^7.0.1
//   wakelock_plus: ^1.3.2
//   sqflite: ^2.4.2
//   path_provider: ^2.1.5
//   path: ^1.9.1

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep screen on for kiosk usage
  await WakelockPlus.enable();
  runApp(const KioskApp());
}

class KioskApp extends StatelessWidget {
  const KioskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QR Attendance Kiosk',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const ScanKioskScreen(),
    );
  }
}

class ScanKioskScreen extends StatefulWidget {
  const ScanKioskScreen({super.key});

  @override
  State<ScanKioskScreen> createState() => _ScanKioskScreenState();
}

class _ScanKioskScreenState extends State<ScanKioskScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    facing: CameraFacing.front,
    torchEnabled: false,
    detectionSpeed: DetectionSpeed.noDuplicates,
    detectionTimeoutMs: 800,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _isProcessing = false; // throttle between scans
  bool _showSuccess = false;  // overlay control
  String _lastDisplay = '';
  int _totalScans = 0;

  @override
  void initState() {
    super.initState();
    _initDbAndCounts();
  }

  Future<void> _initDbAndCounts() async {
    await AttendanceDb.instance.database; // ensure init
    final count = await AttendanceDb.instance.totalCount();
    if (mounted) setState(() => _totalScans = count);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final codes = capture.barcodes;
    if (codes.isEmpty) return;

    // Pick first non-null string value
    String? raw;
    for (final bc in codes) {
      raw = bc.rawValue ?? bc.displayValue;
      if (raw != null && raw.isNotEmpty) break;
    }
    if (raw == null || raw.isEmpty) return;

    _isProcessing = true;

    try {
      final parsed = _parseQrPayload(raw);
      final name = parsed.name ?? '-';
      final card = parsed.card ?? raw; // fall back to raw if no card field

      final now = DateTime.now();
      await AttendanceDb.instance.insertScan(ScanRecord(
        id: null,
        card: card,
        name: name,
        scannedAt: now,
        synced: false,
      ));

      final newTotal = await AttendanceDb.instance.totalCount();

      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _lastDisplay = '${name.isNotEmpty ? name : 'Unknown'}  (Card: $card)';
          _totalScans = newTotal;
          _showSuccess = true;
        });
      }

      // Show success overlay briefly, then resume scanning state
      await Future.delayed(const Duration(milliseconds: 900));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _showSuccess = false);
      }
      _isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          // Camera Preview + Scanner
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _handleDetection,
            ),
          ),

          // Top status bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  const _StatChip(label: 'READY', icon: Icons.camera_alt_rounded),
                  const SizedBox(width: 8),
                  const _StatChip(label: 'Front Cam', icon: Icons.switch_camera_rounded),
                  const Spacer(),
                  _StatChip(label: 'Scans: $_totalScans', icon: Icons.how_to_reg_rounded),
                ],
              ),
            ),
          ),

          // Center instruction frame
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: size.width * 0.72,
                  height: size.width * 0.72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(width: 6, color: Colors.white.withOpacity(0.8)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Show your QR code to the camera',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Success overlay (non-blocking, fades out automatically)
          AnimatedOpacity(
            opacity: _showSuccess ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              color: Colors.black.withOpacity(0.7),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_rounded, size: 120, color: Colors.greenAccent),
                  const SizedBox(height: 16),
                  const Text(
                    'Attendance Recorded',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _lastDisplay,
                    style: const TextStyle(color: Colors.white70, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Bottom actions (torch & admin)
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    // 🔦 Torch button: listen to controller (ValueNotifier<MobileScannerState>)
                    ValueListenableBuilder<MobileScannerState>(
                      valueListenable: _scannerController,
                      builder: (context, state, _) {
                        final torchState = state.torchState;
                        final unavailable = torchState == TorchState.unavailable;

                        IconData icon;
                        String label;
                        switch (torchState) {
                          case TorchState.on:
                            icon = Icons.flash_on_rounded;
                            label = 'Torch ON';
                            break;
                          case TorchState.off:
                            icon = Icons.flash_off_rounded;
                            label = 'Torch OFF';
                            break;
                          case TorchState.unavailable:
                          default:
                            icon = Icons.flash_off_rounded;
                            label = 'Torch N/A';
                        }

                        return ElevatedButton.icon(
                          onPressed: unavailable
                              ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Torch not available on this device')),
                            );
                          }
                              : () {
                            _scannerController.toggleTorch();
                          },
                          icon: Icon(icon),
                          label: Text(label),
                        );
                      },
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () async {
                        // Admin view: show last 10 records
                        final last = await AttendanceDb.instance.lastScans(limit: 10);
                        if (!mounted) return;
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          builder: (ctx) {
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Recent Scans', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  ...last.map((r) => ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.qr_code_2_rounded),
                                    title: Text(r.name?.isNotEmpty == true ? r.name! : 'Unknown'),
                                    subtitle: Text('Card: ${r.card}  •  ${r.scannedAt}'),
                                  )),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      icon: const Icon(Icons.admin_panel_settings_rounded),
                      label: const Text('Admin'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  ParsedCode _parseQrPayload(String raw) {
    // Try JSON first: {"card":"12345","name":"John Doe"}
    try {
      final obj = jsonDecode(raw);
      if (obj is Map) {
        String? card;
        String? name;
        // Flexible keys
        for (final k in obj.keys) {
          final key = k.toString().toLowerCase();
          final v = obj[k]?.toString();
          if (v == null) continue;
          if (key.contains('card') || key == 'id' || key == 'emp_id') card = v;
          if (key.contains('name') || key == 'emp_name') name = v;
        }
        if (card != null || name != null) return ParsedCode(card: card, name: name);
      }
    } catch (_) {
      // not JSON — continue
    }

    // Try key=value pairs: card=12345;name=John Doe
    final kvPairs = RegExp(r'([a-zA-Z_]+)\s*=\s*([^;|,]+)')
        .allMatches(raw)
        .map((m) => MapEntry(m.group(1)!.toLowerCase(), m.group(2)!.trim()))
        .toList();
    if (kvPairs.isNotEmpty) {
      String? card;
      String? name;
      for (final e in kvPairs) {
        if (e.key.contains('card') || e.key == 'id' || e.key == 'emp_id') card = e.value;
        if (e.key.contains('name') || e.key == 'emp_name') name = e.value;
      }
      return ParsedCode(card: card, name: name);
    }

    // Fallback split patterns: 12345|John Doe  OR  12345,John Doe
    for (final sep in ['|', ',', ';']) {
      final parts = raw.split(sep).map((s) => s.trim()).toList();
      if (parts.length >= 2) {
        final p0 = parts.first;
        final p1 = parts.sublist(1).join(' ');
        return ParsedCode(card: p0, name: p1);
      }
    }

    // Final fallback: return raw as card
    return ParsedCode(card: raw, name: null);
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

// ---- Data Layer ----
class ScanRecord {
  final int? id;
  final String card;
  final String? name;
  final DateTime scannedAt;
  final bool synced;

  ScanRecord({
    required this.id,
    required this.card,
    required this.name,
    required this.scannedAt,
    required this.synced,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'card': card,
    'name': name,
    'scanned_at': scannedAt.toIso8601String(),
    'synced': synced ? 1 : 0,
  };

  factory ScanRecord.fromMap(Map<String, dynamic> m) => ScanRecord(
    id: m['id'] as int?,
    card: m['card'] as String,
    name: m['name'] as String?,
    scannedAt: DateTime.parse(m['scanned_at'] as String),
    synced: (m['synced'] as int) == 1,
  );
}

class ParsedCode {
  final String? card;
  final String? name;
  ParsedCode({this.card, this.name});
}

class AttendanceDb {
  AttendanceDb._();
  static final AttendanceDb instance = AttendanceDb._();

  static const _dbName = 'attendance.db';
  static const _table = 'scans';

  Database? _db;
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            card TEXT NOT NULL,
            name TEXT,
            scanned_at TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          );
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_scans_synced ON $_table(synced);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_scans_time ON $_table(scanned_at DESC);');
      },
    );
  }

  Future<int> insertScan(ScanRecord rec) async {
    final db = await database;
    return db.insert(_table, rec.toMap());
  }

  Future<int> totalCount() async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM $_table');
    return (r.first['c'] as int?) ?? 0;
  }

  Future<List<ScanRecord>> lastScans({int limit = 20}) async {
    final db = await database;
    final rows = await db.query(
      _table,
      orderBy: 'scanned_at DESC',
      limit: limit,
    );
    return rows.map((m) => ScanRecord.fromMap(m)).toList();
  }

  Future<List<ScanRecord>> pendingSync() async {
    final db = await database;
    final rows = await db.query(_table, where: 'synced = 0', orderBy: 'scanned_at ASC');
    return rows.map((m) => ScanRecord.fromMap(m)).toList();
  }

  Future<void> markSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final id in ids) {
      batch.update(_table, {'synced': 1}, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }
}
