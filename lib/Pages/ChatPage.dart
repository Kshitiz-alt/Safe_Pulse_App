import 'package:flutter/material.dart';

class ChatPage extends StatelessWidget {
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
                      "Chat",
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

              // Chat List
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _buildChatItem(
                        "Alice", "assets/person.jpg", "Hi, how are you?"),
                    _buildChatItem(
                        "Bob", "assets/person.jpg", "I'm on my way!"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatItem(String name, String imagePath, String message) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: AssetImage(imagePath),
      ),
      title: Text(name),
      subtitle: Text(message),
      onTap: () {
        // Navigate to chat details
      },
    );
  }
}
