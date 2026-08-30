import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:Safe_pulse/Api/ApiService.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool canResend = true;
  int seconds = 30;
  Timer? timer;

  String? email;

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  Future<void> _loadEmail() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      email = prefs.getString("username");
    });
  }

  /// 🔁 Resend Email API
  Future<void> resendVerificationEmail() async {
    if (email == null) return;

    final response = await http.get(
      Uri.parse(
        "${ApiService.baseUrl}/register/resendVerificationEmail/resendVerification?email=$email",
      ),
    );

    if (response.statusCode == 200) {
      _showSnack("Verification email sent");
      _startTimer();
    } else {
      _showSnack("Failed to resend email");
    }
  }

  /// ⏱ Timer for resend
  void _startTimer() {
    setState(() {
      canResend = false;
      seconds = 30;
    });

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (seconds == 0) {
        t.cancel();
        setState(() => canResend = true);
      } else {
        setState(() => seconds--);
      }
    });
  }

  /// 📧 Open mail app
  Future<void> openEmailApp() async {
    final Uri emailUri = Uri.parse("mailto:");
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Verify Email"),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            /// 📧 Icon
            const Icon(Icons.mark_email_unread_rounded,
                size: 80, color: Colors.blue),

            const SizedBox(height: 24),

            /// Title
            const Text(
              "Check your email",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            /// Subtitle
            Text(
              email != null
                  ? "We’ve sent a verification link to\n$email"
                  : "We’ve sent a verification link",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 30),

            /// 📬 Open Mail Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: openEmailApp,
                icon: const Icon(Icons.open_in_new),
                label: const Text("Open Email App"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 12),

            /// 🔁 Resend Button
            TextButton(
              onPressed: canResend ? resendVerificationEmail : null,
              child: Text(
                canResend
                    ? "Resend Email"
                    : "Retry in $seconds s",
              ),
            ),

            const SizedBox(height: 20),

            /// ✅ Continue Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context); // go back to login
                },
                child: const Text("I've Verified, Continue"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}