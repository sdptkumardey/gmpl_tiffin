import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'employee_db.dart';
import 'tiffin_db.dart';

class ScanAttendancePage extends StatefulWidget {
  const ScanAttendancePage({super.key});

  @override
  State<ScanAttendancePage> createState() => _ScanAttendancePageState();
}

class _ScanAttendancePageState extends State<ScanAttendancePage> {
  late MobileScannerController _scannerController;
  int _totalScans = 0; // will show only unsynced scans
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();

    _scannerController = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,
      detectionSpeed: DetectionSpeed.noDuplicates,
      detectionTimeoutMs: 800,
      formats: const [BarcodeFormat.qrCode],
    );

    _initCount();
  }

  Future<void> _initCount() async {
    final unsynced = await TiffinDb.instance.getUnsynced();
    if (mounted) setState(() => _totalScans = unsynced.length);
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

    String? raw;
    for (final bc in codes) {
      raw = bc.rawValue ?? bc.displayValue;
      if (raw != null && raw.isNotEmpty) break;
    }
    if (raw == null || raw.isEmpty) return;

    _isProcessing = true;

    try {
      final parts = raw.split(":");
      if (parts.length < 3) {
        _navigateToResult(false, "Invalid QR format", "");
        return;
      }

      final empId = parts[0].trim();
      final pfId = parts[1].trim();
      final name = parts.sublist(2).join(":").trim();

      final emp = await EmployeeDb.instance.getEmployeeById(empId);
      if (emp == null) {
        _navigateToResult(false, "Employee not found!", pfId);
      } else {
        // ✅ Check if last scan is within 5 minutes
        final lastRecord = await TiffinDb.instance.getLastScanForEmployee(emp.id);
        if (lastRecord != null) {
          final diff = DateTime.now().difference(lastRecord.scannedOn);
          if (diff.inMinutes < 5) {
            _navigateToResult(
              false,
              "Scan not allowed within 5 minutes",
              emp.pfId,
            );
            _isProcessing = false;
            return;
          }
        }

        // ✅ Otherwise insert new scan
        final now = DateTime.now();
        final record = TiffinRecord(
          gmplEmpRecord: emp.id,
          gmplEmpDept: emp.gmplEmpDept,
          gmplEmpDeptName: emp.gmplEmpDeptName,
          pfId: emp.pfId,
          name: emp.name,
          employee: emp.id,
          scannedOn: now,
          synced: false,
        );
        await TiffinDb.instance.insertScan(record);

        await _initCount();
        _navigateToResult(true, emp.name, emp.pfId);
      }
    } catch (e) {
      _navigateToResult(false, "Error: $e", "");
    } finally {
      _isProcessing = false;
    }
  }

  void _navigateToResult(bool success, String message, String cardNo) async {
    // Stop camera before showing result page
    await _scannerController.stop();

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultPage(
          isSuccess: success,
          message: message,
          cardNo: cardNo,
        ),
      ),
    );

    // Resume camera after coming back
    await _scannerController.start();
  }


  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _handleDetection,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  const _StatChip(label: 'READY', icon: Icons.camera_alt_rounded),
                  const SizedBox(width: 8),
                  const _StatChip(label: 'Back Cam', icon: Icons.switch_camera_rounded),
                  const Spacer(),
                  _StatChip(label: 'Pending: $_totalScans', icon: Icons.how_to_reg_rounded),
                ],
              ),
            ),
          ),
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
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _StatChip({required this.label, required this.icon});

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

class ResultPage extends StatefulWidget {
  final bool isSuccess;
  final String message;
  final String cardNo; // actually pfId now

  const ResultPage({
    super.key,
    required this.isSuccess,
    required this.message,
    required this.cardNo,
  });

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();

    // Play sound
    _playSound();

    // Auto return after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _playSound() async {
    final file = widget.isSuccess ? "assets/sounds/success.mp3" : "assets/sounds/fail.mp3";
    await _player.play(AssetSource(file.replaceFirst("assets/", "")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isSuccess ? Colors.green[900] : Colors.red[900],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.isSuccess ? Icons.verified_rounded : Icons.error_rounded,
              size: 120,
              color: Colors.white,
            ),
            const SizedBox(height: 20),
            Text(
              widget.isSuccess ? "SUCCESS" : "FAILED",
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              widget.message,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (widget.cardNo.isNotEmpty)
              Text(
                "Card No: ${widget.cardNo}", // now shows pfId
                style: const TextStyle(fontSize: 22, color: Colors.white70),
              ),
          ],
        ),
      ),
    );
  }
}
