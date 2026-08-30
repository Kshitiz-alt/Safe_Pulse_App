import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:Safe_pulse/Api/ApiService.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SendLocationPage extends StatefulWidget {
  const SendLocationPage({super.key});

  @override
  State<SendLocationPage> createState() => _SendLocationPageState();
}

class _SendLocationPageState extends State<SendLocationPage> {
  String _status = 'Click the button to send pending locations';

  Future<void> sendPendingLocations() async {
    final List<Map<String, dynamic>> pendingLocations = [];

    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('username');
      final pending = prefs.getString('pending_locations');

      if (userEmail == null) {
        setState(() {
          _status = "User email not found!";
        });
        return;
      }

      if (pending != null) {
        final List<dynamic> decoded = jsonDecode(pending);
        pendingLocations.addAll(decoded.cast<Map<String, dynamic>>());
        log("Loaded ${pendingLocations.length} pending locations");
      }

      if (pendingLocations.isEmpty) {
        setState(() {
          _status = "No pending locations to send.";
        });
        return;
      }

      final url = Uri.parse(
          '${ApiService.baseUrl}/api/rest/bulk-location-save?username=$userEmail');
      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode(pendingLocations);

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        log("Successfully sent ${pendingLocations.length} pending locations");
        await prefs.remove('pending_locations');
        setState(() {
          _status = "Successfully sent ${pendingLocations.length} locations.";
        });
      } else {
        log("Failed to send locations: ${response.statusCode}");
        setState(() {
          _status = "Failed to send. Status code: ${response.statusCode}";
        });
      }
    } catch (e) {
      log("Error sending pending locations: $e");
      setState(() {
        _status = "Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Pending Locations')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_status, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: sendPendingLocations,
              child: const Text("Send Pending Locations"),
            ),
          ],
        ),
      ),
    );
  }
}
