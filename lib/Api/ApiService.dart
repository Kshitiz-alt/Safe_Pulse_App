import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Base URL for the API
  // static const String _baseUrl = "${ApiService.baseUrl}";

  static const String _baseUrl = 'http://147.93.108.99:7072'; //live
  static const String baseUrl = 'http://147.93.108.99:7072';
  // static const String _baseUrl = "http://192.168.29.139:7072"; //local
  // static const String baseUrl = "http://192.168.29.139:7072";
  // // final String _baseUrl = 'http://147.93.108.99:8000';

  Future<Map<String, dynamic>> diagnoseSkin(File imageFile) async {
    print("ytjujghykhkhjlhj ");
    try {
      var request = http.MultipartRequest(
          'POST', Uri.parse('http://147.93.108.99:8000/predict'));
      request.files
          .add(await http.MultipartFile.fromPath('file', imageFile.path));

      var response = await request.send();
      print("ytjujghykhkhjlhj ${response}");
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();

        print("fghfjghjghkghkgkhdata $respStr");
        return jsonDecode(respStr);
      } else {
        return {'error': 'Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'error': 'Failed to connect to the server: $e'};
    }
  }

  // Register API function
  Future<dynamic> registerUser({
    required String userName,
    required String email,
    required String password,
    required String mobileNo,
    // required bool isDoctor,
    required bool registrationTermCondition,
  }) async {
    final url = Uri.parse("$_baseUrl/register");

    // Request body
    final Map<String, dynamic> body = {
      "userName": userName,
      "email": email,
      "password": password,
      "mobileNo": mobileNo,
      "registrationTermCondition": registrationTermCondition,
    };
//   "isDoctor": isDoctor,
    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Parse and return the response
        return response.body;
      } else {
        throw Exception("Failed to register user: ${response.body}");
      }
    } catch (e) {
      throw Exception("Error during registration: $e");
    }
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final token = await getToken();

    print("TOKEN: $token"); // 🔥 ADD THIS

    if (token == null) {
      throw Exception("Token is NULL — user not logged in properly");
    }

    final url = "$baseUrl/auth/change-password";
    print("URL: $url");

    final response = await http.post(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "oldPassword": oldPassword,
        "newPassword": newPassword,
      }),
    );

    print("CHANGE PASS STATUS: ${response.statusCode}");
    print("BODY: ${response.body}");

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }
  }

  Future<bool> getDoctorProfile(String authToken) async {
    final url =
        Uri.parse("${ApiService.baseUrl}/api/doctors/get-doctor-profile");

    try {
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $authToken",
        },
      );

      if (response.statusCode == 200) {
        print("Doctor Profile Data: ${response.body}");
        return true; // Success
      } else {
        print("Error Fetching Doctor Profile: ${response.body}");
        return false; // Failed request
      }
    } catch (e) {
      print("Exception: $e");
      return false; // Error occurred
    }
  }

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString("jwtToken");
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("jwtToken", token);
  }

  // Future<bool> getUserProfile(String authToken) async {
  //   final url = Uri.parse("${ApiService.baseUrl}/api/profile/get-userProfile");

  //   try {
  //     final response = await http.get(
  //       url,
  //       headers: {
  //         "Auth": "Bearer $authToken",
  //       },
  //     );

  //     if (response.statusCode == 200) {
  //       print("dfgbfdhgfhjgfyjgyht ${response.body}");
  //       return true; // Success
  //     } else {
  //       print("dfgbfdhgfhjgfyjgyht ${response.body}");
  //       return false; // Failed request
  //     }
  //   } catch (e) {
  //     return false; // Error occurred
  //   }
  // }

  Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$_baseUrl/auth/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "email": email,
        "password": password,
      }),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);

      // Store the tokens in SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString("jwtToken", responseData["jwtToken"]);
      await prefs.setBool("tempPassword", responseData["tempPassword"]);
      await prefs.setString("refreshToken", responseData["refreshToken"]);
      await prefs.setString("username", responseData["username"]);
      await prefs.setString("userId", responseData["userId"]);
      await prefs.setString("role", responseData["role"]);
      print("dvffghbfhngfjgh ${response.body}");
      print("STATUS: ${response.statusCode}");
      print("BODY: ${response.body}");
      return responseData;
    } else {
      throw Exception('Login failed: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> fetchDiseaseDetails(int diseaseId) async {
    final url = Uri.parse('$_baseUrl/api/diseases/$diseaseId');
    print('$_baseUrl/api/diseases/$diseaseId');
    final response = await http.get(
      url,
      headers: {'Content-Type': 'application/json'},
    );
    print("dfgbfdhgfhjgfyjgyht ${response.body}");
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch disease details: ${response.body}');
    }
  }

  Future<void> forgotPassword({required String email}) async {
    final url = Uri.parse("$baseUrl/auth/forgot-password?email=$email");

    final response = await http.post(url);

    if (response.statusCode != 200) {
      throw Exception("Failed to reset password");
    }
  }

  Future<void> updateNotificationToken(String newToken) async {
    print("edfrghyfghjngfjgfhj");
    final url = Uri.parse(
        '$baseUrl/notification/update-notification-token?newToken=$newToken');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("jwtToken");

    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    print("Notification Token Update Response: ${response.body}");

    if (response.statusCode == 200) {
      print("Notification token updated successfully.");
    } else {
      throw Exception('Failed to update notification token');
    }
  }

  Future<Map<String, dynamic>> getUserProfilenew() async {
    final url = Uri.parse('$baseUrl/api/profile/get-userProfile');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("jwtToken");
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );
    print("FDgdhgfjhfjfgjf  ${response.body}");
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load profile');
    }
  }

  Future<void> uploadDiseaseHistory(File file, String disease) async {
    final url = Uri.parse('$baseUrl/api/disease/history/upload');

    // Get the JWT token from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("jwtToken");

    if (token == null) {
      throw Exception('Token is not available');
    }

    var request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token' // Authorization header
      ..fields['disease'] = disease // Adding the disease field
      ..files.add(await http.MultipartFile.fromPath(
          'file', file.path)); // Adding the file

    try {
      final response = await request.send(); // Sending the request

      if (response.statusCode == 200) {
        print('File uploaded successfully');
      } else {
        print('Failed to upload file: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
      throw Exception('Failed to upload file');
    }
  }

// Function to create SafeZone
  Future<Map<String, dynamic>> createSafeZone(
      Map<String, dynamic> zoneData) async {
    final url = Uri.parse('$baseUrl/api/zones');

    print("Wedsfgdsgtfdgdfhdfhf $zoneData ");
    // Get the JWT token from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("jwtToken");

    if (token == null) {
      throw Exception('Token is not available');
    }

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(zoneData),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create safe zone: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getUserZones(String email) async {
    final url = Uri.parse('$baseUrl/api/zones/user/$email');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("jwtToken");

    if (token == null) {
      throw Exception('Token is not available');
    }

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to fetch user zones: ${response.body}');
    }
  }

  Future<String> deleteZoneById(String zoneId, String email) async {
    final url = Uri.parse('$baseUrl/api/zones/$zoneId?email=$email');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("jwtToken");

    if (token == null) {
      throw Exception('Token is not available');
    }

    final response = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Failed to delete zone: ${response.body}');
    }
  }

  // Function to fetch disease history
  Future<List<Map<String, dynamic>>> getDiseaseHistory() async {
    final url = Uri.parse('$baseUrl/api/disease/history/get-all-history');

    // Get the JWT token from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("jwtToken");

    if (token == null) {
      throw Exception('Token is not available');
    }

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => item as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load disease history');
    }
  }

  // Get user profile
  Future<Map<String, dynamic>> getUserProfile() async {
    final url = Uri.parse('$baseUrl/api/profile/get-userProfile');

    // Get the JWT token from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("jwtToken");

    if (token == null) {
      throw Exception('Token is not available');
    }

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data == null || data.isEmpty) {
        return {}; // fallback empty profile
      }

      return data;
    } else {
      print("PROFILE ERROR: ${response.body}");
      return {}; // 🚀 don't throw
    }
  }

  // Create user profile
  Future<Map<String, dynamic>> createProfile({
    required Map<String, dynamic> userProfile,
    required String? profileImagePath,
  }) async {
    //  print("dfsgbdghfghgfjgfjfjj $userProfile");
    final url = Uri.parse('$baseUrl/api/profile/createProfile');

    // Get the JWT token from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("jwtToken");

    if (token == null) {
      throw Exception('Token is not available');
    }
    print("dfsgbdghfghgfjgfjfjj $userProfile $token");
    // Create multipart request
    var request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromString(
      'userProfile',
      jsonEncode(userProfile),
      contentType: MediaType('application', 'json'),
    ));

    // Add image if available
    if (profileImagePath != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'profileImg',
        profileImagePath,
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    // // Add user profile as JSON
    // request.fields['userProfile'] = jsonEncode(userProfile);

    // // Add profile image if provided
    // if (profileImagePath != null) {
    //   request.files.add(await http.MultipartFile.fromPath(
    //     'profileImg',
    //     profileImagePath,
    //   ));
    // }
    print("dsgsgdfhgfydhjfgjf ${request.files}");
    // Send request
    var response = await request.send();
    var responseData = await response.stream.bytesToString();
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(responseData);
    } else {
      throw Exception('Failed to create profile: ${responseData}');
    }
  }

  // Update user profile
  Future<Map<String, dynamic>> updateProfile({
    required Map<String, dynamic> userProfile,
    required String? profileImagePath,
  }) async {
    final url = Uri.parse('$baseUrl/api/profile/updateProfile');

    // Get the JWT token from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("jwtToken");

    if (token == null) {
      throw Exception('Token is not available');
    }

    // Create multipart request
    var request = http.MultipartRequest('PUT', url);
    request.headers['Authorization'] = 'Bearer $token';

    // // Add user profile as JSON
    // request.fields['userProfile'] = jsonEncode(userProfile);

    // // Add profile image if provided
    // if (profileImagePath != null) {
    //   request.files.add(await http.MultipartFile.fromPath(
    //     'profileImg',
    //     profileImagePath,
    //   ));
    // }
    request.files.add(http.MultipartFile.fromString(
      'userProfile',
      jsonEncode(userProfile),
      contentType: MediaType('application', 'json'),
    ));

    // Add image if available
    if (profileImagePath != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'profileImg',
        profileImagePath,
        contentType: MediaType('image', 'jpeg'),
      ));
    }
    // Send request
    var response = await request.send();
    var responseData = await response.stream.bytesToString();

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(responseData);
    } else {
      throw Exception('Failed to update profile: ${responseData}');
    }
  }

  Future<Map<String, dynamic>> getEmergencyContacts(String userId) async {
    final url = Uri.parse('$baseUrl/api/emergency-contacts/$userId');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      print('Emergency contacts: ${response.body}');
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch emergency contacts');
    }
  }

  Future<void> updateEmergencyContacts({
    required String userId, // e.g., "68245dae1ad1e1353029add5"
    required String ambulance,
    required String police,
    required String fire,
    required String emergency,
  }) async {
    print("sdfvsgdfghfdhdjdjdfd $userId");
    final url = Uri.parse('$baseUrl/api/emergency-contacts/$userId');

    final Map<String, String> body = {
      'ambulance': ambulance,
      'police': police,
      'fire': fire,
      'emergency': emergency,
    };

    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 204) {
      print('Emergency contacts updated successfully.');
    } else {
      print(
          'Failed to update emergency contacts. Status code: ${response.statusCode}');
      throw Exception('Failed to update emergency contacts');
    }
  }

  Future<List<Map<String, dynamic>>> getMyContacts({
    required String userId,
  }) async {
    print("sdfvsgdfghfdhdjdjdfd $userId");
    final url =
        Uri.parse('$baseUrl/api/relationships/get-all-my-contact/$userId');

    final request = http.Request('GET', url)
      ..headers['Content-Type'] = 'text/plain'
      ..body = jsonEncode({});

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      print('Contacts: ${response.body}');
      final List<dynamic> contactsJson = jsonDecode(response.body);
      return contactsJson.cast<Map<String, dynamic>>();
    } else {
      print("sdfvsgdfghfdhdjdjdfd 1 ${response.body}");
      print('Failed to fetch contacts. Status: ${response.statusCode}');
      throw Exception('Failed to get contacts');
    }
  }
}
