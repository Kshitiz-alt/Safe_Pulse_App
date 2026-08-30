import 'package:flutter/material.dart';

import 'package:Safe_pulse/Api/ApiService.dart';

class ChangePasswordPage extends StatefulWidget {
  @override
  _ChangePasswordPageState createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();

  String oldPassword = "";
  String newPassword = "";
  String confirmPassword = "";

  bool isLoading = false;

  final ApiService apiService = ApiService();

  void changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // 🔥 Call your backend API
      await apiService.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Password changed successfully"),
          backgroundColor: Colors.green,
        ),
      );

      // ✅ Navigate to main app after success
      Navigator.pushReplacementNamed(context, "/home");

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to change password"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // 🚫 prevent back
      child: Scaffold(
        appBar: AppBar(title: Text("Change Password")),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  decoration: InputDecoration(labelText: "Old Password"),
                  obscureText: true,
                  onSaved: (val) => oldPassword = val!,
                  validator: (val) =>
                      val!.isEmpty ? "Enter old password" : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(labelText: "New Password"),
                  obscureText: true,
                  onSaved: (val) => newPassword = val!,
                  validator: (val) =>
                      val!.length < 6 ? "Min 6 characters" : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(labelText: "Confirm Password"),
                  obscureText: true,
                  onSaved: (val) => confirmPassword = val!,
                  validator: (val) =>
                      val!.isEmpty ? "Confirm password" : null,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isLoading ? null : changePassword,
                  child: isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text("Update Password"),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}