import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({Key? key}) : super(key: key);

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1F2333),
        ),
      ),
    );
  }

  Widget _sectionText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        height: 1.6,
        color: Color(0xFF7B8094),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text("Privacy Policy"),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListView(
            children: [
              const Text(
                "SafePulse Privacy Policy",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2333),
                ),
              ),

              const SizedBox(height: 10),

              _sectionText(
                "Your privacy is important to us. This Privacy Policy explains how SafePulse collects, uses, and protects your information.",
              ),

              _sectionTitle("1. Information We Collect"),
              _sectionText(
                "We may collect personal information such as your name, email address, and location data when you use our services.",
              ),

              _sectionTitle("2. Location Data"),
              _sectionText(
                "SafePulse uses your location to provide real-time tracking and safety features. Location data is only shared with users you explicitly connect with.",
              ),

              _sectionTitle("3. How We Use Your Data"),
              _sectionText(
                "We use your data to provide and improve our services, ensure user safety, and enhance your overall experience.",
              ),

              _sectionTitle("4. Data Security"),
              _sectionText(
                "We implement strong security measures to protect your personal data from unauthorized access.",
              ),

              _sectionTitle("5. Sharing of Information"),
              _sectionText(
                "We do not sell your personal data. Your information is only shared with your approved connections.",
              ),

              _sectionTitle("6. Your Rights"),
              _sectionText(
                "You can request access, correction, or deletion of your data at any time.",
              ),

              _sectionTitle("7. Updates to Policy"),
              _sectionText(
                "We may update this Privacy Policy from time to time. Changes will be reflected on this page.",
              ),

              const SizedBox(height: 20),

              const Text(
                "Last updated: July 2026",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}