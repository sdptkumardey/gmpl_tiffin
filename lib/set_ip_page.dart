import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SetIpPage extends StatefulWidget {
  @override
  State<SetIpPage> createState() => _SetIpPageState();
}

class _SetIpPageState extends State<SetIpPage> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadIp();
  }

  void _loadIp() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('ip') ?? '';
    _controller.text = savedIp;
  }

  void _saveIp() async {
    final ip = _controller.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter an IP address')),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ip', ip);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('IP saved: $ip')),
    );
    Navigator.pop(context); // Go back to previous screen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Set IP', style: TextStyle(color: Colors.white),),
        backgroundColor: Color(0xFF104270),
        iconTheme: IconThemeData(color: Colors.white),  // <-- This makes the back button white
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'IP Address',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.save, color: Colors.white,),
                label: Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF104270),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _saveIp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
