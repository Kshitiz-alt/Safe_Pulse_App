// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:http/http.dart' as http;
// import 'package:http_parser/http_parser.dart';

// class CreateProfilePage extends StatefulWidget {
//   final String authToken;

//   const CreateProfilePage({Key? key, required this.authToken})
//       : super(key: key);

//   @override
//   _CreateProfilePageState createState() => _CreateProfilePageState();
// }

// class _CreateProfilePageState extends State<CreateProfilePage> {
//   final _formKey = GlobalKey<FormState>();
//   final _firstNameController = TextEditingController();
//   final _lastNameController = TextEditingController();
//   final _mobileController = TextEditingController();
//   String _gender = 'Male';
//   DateTime _selectedDate = DateTime.now();
//   File? _profileImage;

//   Future<void> _selectDate(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _selectedDate,
//       firstDate: DateTime(1900),
//       lastDate: DateTime.now(),
//     );
//     if (picked != null && picked != _selectedDate) {
//       setState(() {
//         _selectedDate = picked;
//       });
//     }
//   }

//   Future<void> _pickImage() async {
//     final picker = ImagePicker();
//     final pickedFile = await picker.pickImage(source: ImageSource.gallery);

//     if (pickedFile != null) {
//       setState(() {
//         _profileImage = File(pickedFile.path);
//       });
//     }
//   }

//   Future<void> _submitProfile() async {
//     if (!_formKey.currentState!.validate()) return;

//     // Format the date as YYYY-MM-DD
//     final formattedDate =
//         "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

//     // Create the profile JSON
//     final profileJson = {
//       "firstName": _firstNameController.text,
//       "lastName": _lastNameController.text,
//       "gender": _gender,
//       "dateOfBirth": formattedDate,
//       "mobile": _mobileController.text,
//     };

//     // Create the multipart request
//     var request = http.MultipartRequest(
//       'POST',
//       Uri.parse('http://147.93.108.99:7072/api/profile/createProfile'),
//     );

//     // Add headers
//     request.headers['Auth'] = 'Bearer ${widget.authToken}';

//     // Add profile JSON
//     request.fields['userProfile'] = profileJson.toString();

//     // Add image file if selected
//     if (_profileImage != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'profileImg',
//           _profileImage!.path,
//           contentType:
//               MediaType('image', 'jpeg'), // Adjust content type as needed
//         ),
//       );
//     }

//     try {
//       final response = await request.send();
//       final responseBody = await response.stream.bytesToString();

//       if (response.statusCode == 200) {
//         // Success
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Profile created successfully!')),
//         );
//       } else {
//         // Error
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//               content: Text('Error: ${response.statusCode} - $responseBody')),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error: $e')),
//       );
//     }
//   }

//   @override
//   void dispose() {
//     _firstNameController.dispose();
//     _lastNameController.dispose();
//     _mobileController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Create Profile'),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             children: [
//               GestureDetector(
//                 onTap: _pickImage,
//                 child: CircleAvatar(
//                   radius: 50,
//                   backgroundImage:
//                       _profileImage != null ? FileImage(_profileImage!) : null,
//                   child: _profileImage == null
//                       ? const Icon(Icons.add_a_photo, size: 40)
//                       : null,
//                 ),
//               ),
//               const SizedBox(height: 20),
//               TextFormField(
//                 controller: _firstNameController,
//                 decoration: const InputDecoration(
//                   labelText: 'First Name',
//                   border: OutlineInputBorder(),
//                 ),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter your first name';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               TextFormField(
//                 controller: _lastNameController,
//                 decoration: const InputDecoration(
//                   labelText: 'Last Name',
//                   border: OutlineInputBorder(),
//                 ),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter your last name';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               DropdownButtonFormField<String>(
//                 value: _gender,
//                 decoration: const InputDecoration(
//                   labelText: 'Gender',
//                   border: OutlineInputBorder(),
//                 ),
//                 items: ['Male', 'Female', 'Other']
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
//               ),
//               const SizedBox(height: 16),
//               InkWell(
//                 onTap: () => _selectDate(context),
//                 child: InputDecorator(
//                   decoration: const InputDecoration(
//                     labelText: 'Date of Birth',
//                     border: OutlineInputBorder(),
//                   ),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}",
//                       ),
//                       const Icon(Icons.calendar_today),
//                     ],
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 16),
//               TextFormField(
//                 controller: _mobileController,
//                 decoration: const InputDecoration(
//                   labelText: 'Mobile Number',
//                   border: OutlineInputBorder(),
//                 ),
//                 keyboardType: TextInputType.phone,
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter your mobile number';
//                   }
//                   if (value.length != 10) {
//                     return 'Mobile number must be 10 digits';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 24),
//               ElevatedButton(
//                 onPressed: _submitProfile,
//                 style: ElevatedButton.styleFrom(
//                     minimumSize: const Size(double.infinity, 50)),
//                 child: const Text('Create Profile'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
