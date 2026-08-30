import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:Safe_pulse/Api/ApiService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _apiService.getUserProfile();
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Color(0xFF5C6BC0),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfilePage(
                    userProfile: _userProfile,
                    onProfileUpdated: _loadProfile,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF5C6BC0)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading profile...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProfile,
                        child: Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF5C6BC0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      )
                    ],
                  ),
                )
              : _userProfile == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color: Colors.orange,
                            size: 48,
                          ),
                          SizedBox(height: 16),
                          Text(
                            "No profile data available",
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          // Profile header
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Color(0xFF5C6BC0),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(30),
                                bottomRight: Radius.circular(30),
                              ),
                            ),
                            child: Column(
                              children: [
                                SizedBox(height: 20),
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: _userProfile!['profileImg'] != null
                                        ? CachedNetworkImage(
                                            imageUrl:
                                                '${ApiService.baseUrl}/${_userProfile!['profileImg']}',
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                Container(
                                              color: Colors.grey[200],
                                              child: Icon(Icons.person,
                                                  size: 50,
                                                  color: Colors.grey[400]),
                                            ),
                                            errorWidget: (context, url,
                                                    error) =>
                                                Icon(Icons.person, size: 50),
                                          )
                                        : Image.asset(
                                            'assets/default_profile.png',
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                ),
                                SizedBox(height: 20),
                                Text(
                                  '${_userProfile!['firstName']} ${_userProfile!['lastName']}',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  _userProfile!['email'] ?? 'No email',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                                SizedBox(height: 20),
                              ],
                            ),
                          ),
                          // Profile details
                          Padding(
                            padding: EdgeInsets.all(20),
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    _buildProfileDetailCard(
                                      icon: Icons.person_outline,
                                      title: 'Personal Information',
                                      items: [
                                        _buildDetailItem(
                                            'First Name',
                                            _userProfile!['firstName'] ??
                                                'Not provided'),
                                        _buildDetailItem(
                                            'Last Name',
                                            _userProfile!['lastName'] ??
                                                'Not provided'),
                                        _buildDetailItem(
                                            'Gender',
                                            _userProfile!['gender'] ??
                                                'Not provided'),
                                        _buildDetailItem(
                                            'Date of Birth',
                                            _userProfile!['dateOfBirth'] ??
                                                'Not provided'),
                                        _buildDetailItem(
                                            'Age',
                                            _userProfile!['age']?.toString() ??
                                                'Not provided'),
                                      ],
                                    ),
                                    SizedBox(height: 20),
                                    _buildProfileDetailCard(
                                      icon: Icons.contact_phone,
                                      title: 'Contact Information',
                                      items: [
                                        _buildDetailItem(
                                            'Email',
                                            _userProfile!['email'] ??
                                                'Not provided'),
                                        _buildDetailItem(
                                            'Mobile',
                                            _userProfile!['mobile'] ??
                                                'Not provided'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Logout button
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _logout,
                                icon: Icon(Icons.logout),
                                label: Text('Logout'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildProfileDetailCard({
    required IconData icon,
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Color(0xFF5C6BC0), size: 24),
            SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        SizedBox(height: 15),
        ...items,
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic>? userProfile;
  final VoidCallback onProfileUpdated;

  EditProfilePage({
    required this.userProfile,
    required this.onProfileUpdated,
  });

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;

  // Form fields
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late String _gender;
  late TextEditingController _dateOfBirthController;
  late TextEditingController _mobileController;

  @override
  void initState() {
    super.initState();
    _firstNameController =
        TextEditingController(text: widget.userProfile?['firstName'] ?? '');
    _lastNameController =
        TextEditingController(text: widget.userProfile?['lastName'] ?? '');
    _gender = widget.userProfile?['gender'] ?? 'Male';
    _dateOfBirthController =
        TextEditingController(text: widget.userProfile?['dateOfBirth'] ?? '');
    _mobileController =
        TextEditingController(text: widget.userProfile?['mobile'] ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dateOfBirthController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        final userProfile = {
          'firstName': _firstNameController.text,
          'lastName': _lastNameController.text,
          'gender': _gender,
          'dateOfBirth': _dateOfBirthController.text,
          'mobile': _mobileController.text,
        };

        if (widget.userProfile == null) {
          // Create new profile
          await _apiService.createProfile(
            userProfile: userProfile,
            profileImagePath: _imageFile?.path,
          );
        } else {
          // Update existing profile
          await _apiService.updateProfile(
            userProfile: userProfile,
            profileImagePath: _imageFile?.path,
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onProfileUpdated();
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dateOfBirthController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Color(0xFF5C6BC0),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: Colors.white),
            onPressed: _submitForm,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile image
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Color(0xFF5C6BC0),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _imageFile != null
                            ? Image.file(
                                _imageFile!,
                                fit: BoxFit.cover,
                              )
                            : widget.userProfile?['profileImg'] != null
                                ? CachedNetworkImage(
                                    imageUrl:
                                        '${ApiService.baseUrl}/${widget.userProfile!['profileImg']}',
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey[200],
                                      child: Icon(Icons.person,
                                          size: 50, color: Colors.grey[400]),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Icon(Icons.person, size: 50),
                                  )
                                : Image.asset(
                                    'assets/default_profile.png',
                                    fit: BoxFit.cover,
                                  ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(0xFF5C6BC0),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.camera_alt,
                              size: 20, color: Colors.white),
                          onPressed: _pickImage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 30),
              // Form fields
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildFormField(
                        controller: _firstNameController,
                        label: 'First Name',
                        icon: Icons.person,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your first name';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 15),
                      _buildFormField(
                        controller: _lastNameController,
                        label: 'Last Name',
                        icon: Icons.person,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your last name';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 15),
                      _buildDropdownField(
                        value: _gender,
                        label: 'Gender',
                        icon: Icons.transgender,
                        items: ['Male', 'Female', 'Other'],
                        onChanged: (value) {
                          setState(() {
                            _gender = value!;
                          });
                        },
                      ),
                      SizedBox(height: 15),
                      _buildFormField(
                        controller: _dateOfBirthController,
                        label: 'Date of Birth',
                        icon: Icons.calendar_today,
                        readOnly: true,
                        onTap: () => _selectDate(context),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select your date of birth';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 15),
                      _buildFormField(
                        controller: _mobileController,
                        label: 'Mobile Number',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your mobile number';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 30),
              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF5C6BC0),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Save Profile',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    FormFieldValidator<String>? validator,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Color(0xFF5C6BC0)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Color(0xFF5C6BC0)),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 15),
      ),
      validator: validator,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
    );
  }

  Widget _buildDropdownField({
    required String value,
    required String label,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Color(0xFF5C6BC0)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Color(0xFF5C6BC0)),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 2, horizontal: 15),
      ),
      items: items.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
