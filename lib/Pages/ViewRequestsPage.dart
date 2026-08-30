import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:Safe_pulse/Api/ApiService.dart';

class ViewRequestsPage extends StatefulWidget {
  final String userEmail;

  ViewRequestsPage({required this.userEmail});

  @override
  _ViewRequestsPageState createState() => _ViewRequestsPageState();
}


class _ViewRequestsPageState extends State<ViewRequestsPage> {
  List<dynamic> _requests = [];
  bool _isLoading = false;
  String _message = "";

  Future<void> _fetchRequests() async {
    setState(() {
      _isLoading = true;
      _message = "";
    });

    final String url =
        '${ApiService.baseUrl}/api/relationships/getUserRelations?email=${widget.userEmail}';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _requests = data;
        });
      } else {
        setState(() {
          _message = "Failed to fetch requests. Please try again.";
        });
      }
    } catch (e) {
      setState(() {
        _message = "An error occurred. Please check your connection.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptRequest(String relationId) async {
    final String url =
        '${ApiService.baseUrl}/api/relationships/acceptRequest?relationId=$relationId';

    try {
      final response = await http.post(Uri.parse(url));

      if (response.statusCode == 200) {
        setState(() {
          _message = "Relationship request accepted successfully!";
        });
        _fetchRequests(); // Refresh the list after accepting
      } else {
        setState(() {
          _message = "Failed to accept request. Please try again.";
        });
      }
    } catch (e) {
      setState(() {
        _message = "An error occurred. Please check your connection.";
      });
    }
  }

  void _showAcceptConfirmationModal(String relationId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Acceptance"),
          content: Text("Are you sure you want to accept this request?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the modal
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the modal
                _acceptRequest(relationId); // Accept the request
              },
              child: Text("Accept"),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("View Requests"),
        backgroundColor: Colors.blue[800],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? Center(
                  child: Text(
                    _message.isEmpty ? "No requests found." : _message,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20.0),
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final request = _requests[index];
                    final isConnected = request['isLinked'] == 1.0;
                    final isActive = request['activityStatus'] == "Active";

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ListTile(
                        leading: Icon(Icons.person, color: Colors.blue[800]),
                        title: Text(request['otherUserEmail'] ?? 'No email'),
                        subtitle: Text(
                            "Relationship: ${request['relationName'] ?? 'No relation'}\n"),
                        trailing: isConnected
                            ? Text(
                                "Connected",
                                style: TextStyle(color: Colors.green),
                              )
                            : isActive
                                ? ElevatedButton(
                                    onPressed: () {
                                      _showAcceptConfirmationModal(
                                          request['relationId']);
                                    },
                                    child: Text("Accept"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                    ),
                                  )
                                : Text(
                                    "Pending",
                                    style: TextStyle(color: Colors.orange),
                                  ),
                      ),
                    );
                  },
                ),
    );
  }
}
