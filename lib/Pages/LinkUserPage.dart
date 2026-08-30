import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:Safe_pulse/Api/ApiService.dart';
import 'package:Safe_pulse/Pages/ViewRequestsPage.dart';

class LinkUserPage extends StatefulWidget {
  final String userEmail;

  LinkUserPage({required this.userEmail});

  @override
  _LinkUserPageState createState() => _LinkUserPageState();
}

class _LinkUserPageState extends State<LinkUserPage> {
  final TextEditingController _toEmailController = TextEditingController();

  bool _isLoading = false;
  String? _message;
  bool _isSuccess = false;

  String? _selectedRelation;

  final List<String> relations = [
    "brother",
    "sister",
    "father",
    "mother",
    "friend",
    "Spouse",
    "Guardian",
    "Other"
  ];

  bool _isValidEmail(String email) {
    return RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(email);
  }

  Future<void> _sendRelationshipRequest() async {
    final toEmail = _toEmailController.text.trim();

    if (toEmail.isEmpty || _selectedRelation == null) {
      setState(() {
        _message = "Please fill all fields.";
        _isSuccess = false;
      });
      return;
    }

    if (!_isValidEmail(toEmail)) {
      setState(() {
        _message = "Please enter a valid email address.";
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    final url =
        '${ApiService.baseUrl}/api/relationships/sendRequest'
        '?fromEmail=${widget.userEmail}'
        '&toEmail=$toEmail'
        '&relationName=$_selectedRelation';

    try {
      final response = await http.post(Uri.parse(url));

      if (response.statusCode == 200) {
        setState(() {
          _message = "Request sent successfully!";
          _isSuccess = true;
          _toEmailController.clear();
          _selectedRelation = null;
        });
      } else {
        setState(() {
          _message = "Failed to send request. Try again.";
          _isSuccess = false;
        });
      }
    } catch (e) {
      setState(() {
        _message = "Network error. Please try again.";
        _isSuccess = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildRelationChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: relations.map((rel) {
        final selected = _selectedRelation == rel;

        return ChoiceChip(
          label: Text(rel),
          selected: selected,
          onSelected: (_) {
            setState(() {
              _selectedRelation = rel;
            });
          },
          selectedColor: Colors.blue[800],
          labelStyle: TextStyle(
            color: selected ? Colors.white : Colors.black,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: EdgeInsets.all(20),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 15,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Connect with someone",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Send a relationship request to link accounts",
            style: TextStyle(color: Colors.grey[600]),
          ),

          SizedBox(height: 25),

          // Email field
          TextField(
            controller: _toEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.email_outlined),
              labelText: "Recipient Email",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          SizedBox(height: 20),

          Text(
            "Select Relationship",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 10),

          _buildRelationChips(),

          SizedBox(height: 25),

          // Send button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendRelationshipRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                      "Send Request",
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ),

          SizedBox(height: 15),

          if (_message != null)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isSuccess
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _isSuccess ? Icons.check_circle : Icons.error,
                    color: _isSuccess ? Colors.green : Colors.red,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color: _isSuccess ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildViewRequestsButton() {
    return TextButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ViewRequestsPage(userEmail: widget.userEmail),
          ),
        );
      },
      icon: Icon(Icons.list),
      label: Text("View Requests"),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF4F6FA),

      appBar: AppBar(
        title: Text("Link User"),
        backgroundColor: Colors.blue[800],
        elevation: 0,
      ),

      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          children: [
            SizedBox(height: 10),
            _buildInputCard(),
            _buildViewRequestsButton(),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}