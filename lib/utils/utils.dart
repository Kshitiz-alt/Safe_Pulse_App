String getDisplayName(Map<String, dynamic> relation) {
  final relationName = (relation['relationName'] ?? '').toString().trim();
  final email = (relation['otherUserEmail'] ?? '').toString();

  // extract username from email
  String username = email.contains('@') ? email.split('@')[0] : email;

  // capitalize first letter
  if (username.isNotEmpty) {
    username = username[0].toUpperCase() + username.substring(1);
  }

  if (relationName.isNotEmpty) {
    return "$username ($relationName)";
  } else {
    return username.isNotEmpty ? username : "Unknown";
  }
}

String getNameFromEmail(String email) {
  if (!email.contains('@')) return email;

  String name = email.split('@')[0];

  // Replace separators with space
  name = name.replaceAll(RegExp(r'[._\-]'), ' ');

  // Remove numbers
  name = name.replaceAll(RegExp(r'\d+'), '');

  // Trim extra spaces
  name = name.trim();

  // Capitalize each word
  name = name.split(' ').map((word) {
    if (word.isEmpty) return '';
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');

  return name.isEmpty ? "User" : name;
}