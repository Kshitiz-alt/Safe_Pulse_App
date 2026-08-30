import 'package:Safe_pulse/Pages/ChangePasswordPage.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart'; // Import the Lottie package
import 'package:Safe_pulse/Api/ApiService.dart';
import 'package:Safe_pulse/Signup/Register.dart';
import 'package:Safe_pulse/BottomPages/BottomNav.dart';
import 'package:Safe_pulse/services/background_services.dart';
import 'package:Safe_pulse/utils/oem_auto_start_setup.dart'; // Import the OemAutostartHelper
import 'package:flutter/services.dart'; // For MethodChannel
import 'package:Safe_pulse/services/permission_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
// Import your RegisterPage

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  bool _isLoading = false;
  bool _obscurePassword = true;

  static const String baseUrl = 'http://147.93.108.99:7072'; //live

  final ApiService _apiService = ApiService(); // Instance of ApiService

  // Function to handle login
  void _loginUser() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save(); // Save the form values
      setState(() {
        _isLoading = true;
      });

      try {
        final response = await _apiService.loginUser(
          email: _email.trim(),
          password: _password.trim(),
        );

        final token = response["jwtToken"];
        await _apiService.saveToken(token);

        final prefs = await SharedPreferences.getInstance();

        await prefs.setString("jwtToken", response["jwtToken"]);
        await prefs.setString("userId", response["userId"]);
        await prefs.setString("username", response["username"]);
        await prefs.setString("serverUrl", ApiService.baseUrl);

        // const platform = MethodChannel('safe_pulse/location');

        // await platform.invokeMethod('startLocationService');
        // await platform.invokeMethod('requestBatteryOptimizationExemption');

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: Colors.green,
              content: Text("Login Successful!")),
        );
        final isTempPassword = response["tempPassword"] ?? false;

        if (isTempPassword) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => ChangePasswordPage()),
          );
        } else {
          // ✅ Request permissions FIRST, and wait for them
          await _requestPermissions();

          if (!mounted) return;

// Step 1: Explain battery optimization
          bool allowed = false;

          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text("Allow Background Tracking"),
              content: Text(
                "To keep your live location working even when the app is closed, "
                "please allow battery optimization exemption.",
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    allowed = true;
                    Navigator.pop(context);
                  },
                  child: Text("Allow"),
                ),
              ],
            ),
          );

          if (allowed) {
            const platform = MethodChannel('safe_pulse/location');

            await platform.invokeMethod('requestBatteryOptimizationExemption');
            await platform.invokeMethod('requestExactAlarmPermission'); 
            await OemAutostartHelper.promptIfNeeded(context);
            await platform.invokeMethod('startLocationService');
          } else {
            // Optional: show warning
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text("Tracking may not work properly without this")),
            );
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => BottomNav()),
          );
        }
      } catch (e) {
        // Show error message
        print("Error: hhhh$e");
        print(StackTrace.current);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login failed. Please try again")),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _requestPermissions() async {
    return await PermissionHelper.requestPermissions(context);
  }

  Future<void> forgotPassword({required String email}) async {
    final uri = Uri.parse("$baseUrl/auth/forgot-password").replace(
      queryParameters: {"email": email},
    );

    print("FORGOT URL: $uri");

    final response = await http.post(uri);

    print("STATUS: ${response.statusCode}");
    print("BODY: ${response.body}");

    if (response.statusCode != 200) {
      throw Exception("Failed: ${response.body}");
    }
  }

  @override
  void initState() {
    super.initState();
  }

  void _showForgotPasswordDialog() {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Forgot Password"),
          content: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: "Enter your email",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                final email = emailController.text.trim();

                if (email.isEmpty || !email.contains("@")) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Enter valid email")),
                  );
                  return;
                }

                await forgotPassword(email: email);
                Navigator.pop(context);
              },
              child: Text("Submit"),
            ),
          ],
        );
      },
    );
  }

  // void _checkLogin() async {

  // }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent back navigation
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text("Login"),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                // Add Lottie animation at the top
                Center(
                  child: Lottie.asset(
                    'assets/anima.json', // Path to your Lottie file
                    height: 300,
                    width: 300,
                  ),
                ),
                SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: "Email",
                    hintText: "Enter your email address",
                    prefixIcon: Icon(Icons.email),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none, // Removes the border
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Email cannot be empty";
                    } else if (!RegExp(
                            r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
                        .hasMatch(value)) {
                      return "Please provide a valid email address";
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _email = value!;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: "Password",
                    hintText: "Enter your password",
                    prefixIcon: Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none, // Removes the border
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please enter your password";
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _password = value!;
                  },
                ),
                SizedBox(height: 16),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: Text(
                      "Forgot Password?",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width *
                        0.8, // Responsive width
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : _loginUser, // Disable button while loading
                      child: Padding(
                        padding: const EdgeInsets.all(
                            15.0), // Adjust padding for a better tap area
                        child: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                "Login",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(
                            255, 122, 196, 125), // Match green color
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16), // Rounded corners
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w600),
                        elevation: 5, // Subtle shadow for a raised effect
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 16),
                // Add "Do not have an account? Register" text
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              RegisterPage(), // Navigate to RegisterPage
                        ),
                      );
                    },
                    child: Text(
                      "Don't have an account? Register",
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
