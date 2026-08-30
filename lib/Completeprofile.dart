// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:lottie/lottie.dart';
// import 'package:Safe_pulse/Api/ApiService.dart';
// import 'package:Safe_pulse/BottomPages/BottomNav.dart';

// class CreateProfilePage extends StatefulWidget {
//   @override
//   _CreateProfilePageState createState() => _CreateProfilePageState();
// }

// class _CreateProfilePageState extends State<CreateProfilePage> {
//   final _formKey = GlobalKey<FormState>();
//   bool _isLoading = false;

//   // Form fields
//   String _firstName = '';
//   String _lastName = '';
//   String _gender = 'Female'; // Default gender
//   String _dateOfBirth = '';
//   double _weight = 0.0;
//   int _heightFt = 0;
//   int _heightIn = 0;

//   final TextEditingController _dateController = TextEditingController();
//   // final TextEditingController _dateController = TextEditingController();
//   Future<void> _selectDate(BuildContext context) async {
//     DateTime? pickedDate = await showDatePicker(
//       context: context,
//       initialDate: DateTime.now(),
//       firstDate: DateTime(1900),
//       lastDate: DateTime.now(),
//     );

//     if (pickedDate != null) {
//       String formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);
//       setState(() {
//         _dateOfBirth = formattedDate;
//         _dateController.text = formattedDate;
//       });
//     }
//   }

//   // Function to handle form submission
//   void _submitProfile() async {
//     print("dgvdfyghjgfjfjg ${_dateOfBirth}");
//     if (_formKey.currentState!.validate()) {
//       _formKey.currentState!.save();
//       setState(() {
//         _isLoading = true;
//       });
//       print("dgvdfyghjgfjfjg ${_dateOfBirth}");
//       final Map<String, dynamic> requestBody = {
//         "firstName": _firstName,
//         "lastName": _lastName,
//         "gender": _gender,
//         "dateOfBirth": _dateOfBirth,
//         "weight": _weight,
//         "heightFt": _heightFt,
//         "heightIn": _heightIn,
//       };

//       try {
//         SharedPreferences prefs = await SharedPreferences.getInstance();
//         String? token = prefs.getString("jwtToken");
//         print("Request Body: $requestBody");
//         final response = await http.post(
//           Uri.parse('${ApiService.baseUrl}/api/profile/createProfile'),
//           headers: {
//             'Content-Type': 'application/json',
//             'Auth': 'Bearer $token',
//           },
//           body: json.encode(requestBody),
//         );
//         print("API Response: ${response.body}");
//         if (response.statusCode == 200 || response.statusCode == 201) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               backgroundColor: Colors.green,
//               content: Text("Profile created successfully!"),
//             ),
//           );
//           String? roles = prefs.getString("roles");
//           if (roles != "ROLE_NORMAL") {
//           } else {
//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(
//                   builder: (context) =>
//                       BottomNav()), // Replace with your desired page
//             );
//           }
//         } else {
//           throw Exception("Failed to create profile: ${response.body}");
//         }
//       } catch (e) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("Error: $e")),
//         );
//       } finally {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         title: Text("Create Profile"),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: ListView(
//             children: [
//               // Lottie Animation
//               Center(
//                 child: Lottie.asset(
//                   'assets/anima.json', // Path to your Lottie file
//                   height: 200,
//                   width: 200,
//                 ),
//               ),

//               // First Name Field
//               TextFormField(
//                 decoration: InputDecoration(
//                   labelText: "First Name",
//                   hintText: "Enter your first name",
//                   prefixIcon: Icon(Icons.person),
//                   filled: true,
//                   fillColor: Colors.grey.shade100,
//                   contentPadding:
//                       EdgeInsets.symmetric(vertical: 15, horizontal: 20),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                   errorBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                   focusedErrorBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                 ),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return "Please enter your first name";
//                   }
//                   return null;
//                 },
//                 onSaved: (value) {
//                   _firstName = value!;
//                 },
//               ),
//               SizedBox(height: 16),

//               // Last Name Field
//               TextFormField(
//                 decoration: InputDecoration(
//                   labelText: "Last Name",
//                   hintText: "Enter your last name",
//                   prefixIcon: Icon(Icons.person),
//                   filled: true,
//                   fillColor: Colors.grey.shade100,
//                   contentPadding:
//                       EdgeInsets.symmetric(vertical: 15, horizontal: 20),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                   errorBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                   focusedErrorBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                 ),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return "Please enter your last name";
//                   }
//                   return null;
//                 },
//                 onSaved: (value) {
//                   _lastName = value!;
//                 },
//               ),
//               SizedBox(height: 16),

//               // Gender Dropdown
//               DropdownButtonFormField<String>(
//                 decoration: InputDecoration(
//                   labelText: "Gender",
//                   prefixIcon: Icon(Icons.transgender),
//                   filled: true,
//                   fillColor: Colors.grey.shade100,
//                   contentPadding:
//                       EdgeInsets.symmetric(vertical: 15, horizontal: 20),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                   errorBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                   focusedErrorBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                 ),
//                 value: _gender,
//                 items: ['Female', 'Male', 'Other']
//                     .map((gender) => DropdownMenuItem(
//                           value: gender,
//                           child: Text(gender),
//                         ))
//                     .toList(),
//                 onChanged: (value) {
//                   setState(() {
//                     _gender = value!;
//                   });
//                 },
//                 onSaved: (value) {
//                   _gender = value!;
//                 },
//               ),
//               SizedBox(height: 16),

//               // // Date of Birth Field
//               // TextFormField(
//               //   decoration: InputDecoration(
//               //     labelText: "Date of Birth (YYYY-MM-DD)",
//               //     hintText: "Enter your date of birth",
//               //     prefixIcon: Icon(Icons.calendar_today),
//               //     filled: true,
//               //     fillColor: Colors.grey.shade100,
//               //     contentPadding:
//               //         EdgeInsets.symmetric(vertical: 15, horizontal: 20),
//               //     border: OutlineInputBorder(
//               //       borderRadius: BorderRadius.circular(12),
//               //       borderSide: BorderSide.none,
//               //     ),
//               //     focusedBorder: OutlineInputBorder(
//               //       borderRadius: BorderRadius.circular(12),
//               //       borderSide: BorderSide.none,
//               //     ),
//               //     errorBorder: OutlineInputBorder(
//               //       borderRadius: BorderRadius.circular(12),
//               //       borderSide: BorderSide.none,
//               //     ),
//               //     focusedErrorBorder: OutlineInputBorder(
//               //       borderRadius: BorderRadius.circular(12),
//               //       borderSide: BorderSide.none,
//               //     ),
//               //   ),
//               //   validator: (value) {
//               //     if (value == null || value.isEmpty) {
//               //       return "Please enter your date of birth";
//               //     }
//               //     return null;
//               //   },
//               //   onSaved: (value) {
//               //     _dateOfBirth = value!;
//               //   },
//               // ),

//               TextFormField(
//                 controller: _dateController,
//                 readOnly: true,
//                 decoration: InputDecoration(
//                   labelText: "Date of Birth (YYYY-MM-DD)",
//                   hintText: "Select your date of birth",
//                   prefixIcon: Icon(Icons.calendar_today),
//                   filled: true,
//                   fillColor: Colors.grey.shade100,
//                   contentPadding:
//                       EdgeInsets.symmetric(vertical: 15, horizontal: 20),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                 ),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return "Please select your date of birth";
//                   }
//                   return null;
//                 },
//                 onTap: () {
//                   _selectDate(context);
//                 },
//               ),
//               SizedBox(height: 16),

//               // Weight Field
//               TextFormField(
//                 decoration: InputDecoration(
//                   labelText: "Weight (in kg)",
//                   hintText: "Enter your weight",
//                   prefixIcon: Icon(Icons.monitor_weight),
//                   filled: true,
//                   fillColor: Colors.grey.shade100,
//                   contentPadding:
//                       EdgeInsets.symmetric(vertical: 15, horizontal: 20),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                   errorBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                   focusedErrorBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                 ),
//                 keyboardType: TextInputType.number,
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return "Please enter your weight";
//                   }
//                   return null;
//                 },
//                 onSaved: (value) {
//                   _weight = double.parse(value!);
//                 },
//               ),
//               SizedBox(height: 16),

//               // Height (Feet) Field
//               TextFormField(
//                 decoration: InputDecoration(
//                   labelText: "Height (Feet)",
//                   hintText: "Enter your height in feet",
//                   prefixIcon: Icon(Icons.height),
//                   filled: true,
//                   fillColor: Colors.grey.shade100,
//                   contentPadding:
//                       EdgeInsets.symmetric(vertical: 15, horizontal: 20),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                   errorBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                   focusedErrorBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                 ),
//                 keyboardType: TextInputType.number,
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return "Please enter your height in feet";
//                   }
//                   return null;
//                 },
//                 onSaved: (value) {
//                   _heightFt = int.parse(value!);
//                 },
//               ),
//               SizedBox(height: 16),

//               // Height (Inches) Field
//               TextFormField(
//                 decoration: InputDecoration(
//                   labelText: "Height (Inches)",
//                   hintText: "Enter your height in inches",
//                   prefixIcon: Icon(Icons.height),
//                   filled: true,
//                   fillColor: Colors.grey.shade100,
//                   contentPadding:
//                       EdgeInsets.symmetric(vertical: 15, horizontal: 20),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                   errorBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                   focusedErrorBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                 ),
//                 keyboardType: TextInputType.number,
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return "Please enter your height in inches";
//                   }
//                   return null;
//                 },
//                 onSaved: (value) {
//                   _heightIn = int.parse(value!);
//                 },
//               ),
//               SizedBox(height: 16),

//               // Submit Button
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 20),
//                 child: SizedBox(
//                   width: MediaQuery.of(context).size.width * 0.8,
//                   child: ElevatedButton(
//                     onPressed: _isLoading ? null : _submitProfile,
//                     child: Padding(
//                       padding: const EdgeInsets.all(15.0),
//                       child: _isLoading
//                           ? SizedBox(
//                               height: 20,
//                               width: 20,
//                               child: CircularProgressIndicator(
//                                 strokeWidth: 2,
//                                 color: Colors.white,
//                               ),
//                             )
//                           : Text(
//                               "Submit Profile",
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                     ),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Color.fromARGB(255, 122, 196, 125),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(16),
//                       ),
//                       elevation: 5,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
