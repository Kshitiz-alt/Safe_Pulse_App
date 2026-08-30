import 'package:flutter/material.dart';

class LiveTrackingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (OverscrollIndicatorNotification overscroll) {
            overscroll.disallowIndicator();
            return true;
          },
          child: ListView(
            physics: const ClampingScrollPhysics(),
            shrinkWrap: true,
            children: <Widget>[
              // Header Section
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Live Tracking",
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    IconButton(
                      splashRadius: 20,
                      icon: const Icon(Icons.notifications_active),
                      onPressed: () {
                        // Navigate to notifications
                      },
                    ),
                  ],
                ),
              ),

              // Map Section
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Container(
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.grey[200],
                  ),
                  child: Center(
                    child: Text(
                      "Map Integration Here",
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ),
              ),

              // Child Location Details
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Child Location",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    SizedBox(height: 10),
                    ListTile(
                      leading: Icon(Icons.location_on, color: Colors.blue[800]),
                      title: Text("Alice"),
                      subtitle: Text("Last updated: 10 mins ago"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
