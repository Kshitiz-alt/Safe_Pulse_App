import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:Safe_pulse/Api/ApiService.dart';
import 'package:Safe_pulse/Completeprofile.dart';
import 'package:Safe_pulse/Pages/ChangePasswordPage.dart';
import 'package:Safe_pulse/Pages/PrivacyPolicyPage.dart';
import 'package:Safe_pulse/Pages/LinkUserPage.dart';
import 'package:Safe_pulse/Pages/ProfilePage%20.dart';

import 'package:Safe_pulse/Signup/LoginPage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// -----------------------------------------------------------------------
/// Design tokens — shared visual language with the rest of the app
/// (see UserRelationsPage / ContactPage / ZoneCreationPage).
/// -----------------------------------------------------------------------
class _AppColors {
  static const primary = Color(0xFF5C6BC0);
  static const primaryDark = Color(0xFF3F4BA0);
  static const primarySoft = Color(0xFFE8EAF9);
  static const success = Color(0xFF2E9E5B);
  static const danger = Color(0xFFE0433D);
  static const dangerSoft = Color(0xFFFCEAE9);
  static const surface = Colors.white;
  static const background = Color(0xFFF6F7FB);
  static const textPrimary = Color(0xFF1F2333);
  static const textSecondary = Color(0xFF7B8094);
}

class ProfileManagementPage extends StatefulWidget {
  @override
  State<ProfileManagementPage> createState() => _ProfileManagementPageState();
}

class _ProfileManagementPageState extends State<ProfileManagementPage> {
  String? userEmail;
  String? userName;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  String? _errorMessage;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadProfile();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userEmail = prefs.getString("email") ?? "No email found";
      userName = prefs.getString("name") ?? "User";
    });
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final profile = await _apiService.getUserProfile();
      setState(() {
        _userProfile = profile;
        print("PROFILE RESPONSE: $_userProfile");
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out?'),
        content: const Text('You\'ll need to sign in again to access your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _logout();
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  // ---------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------
  Widget _buildProfileHeader() {
    final profileImg = _userProfile?['profileImg'];
    final displayName = _userProfile != null
        ? "${_userProfile!['firstName'] ?? ''} ${_userProfile!['lastName'] ?? ''}".trim()
        : (userName ?? "User");
    final displayEmail = _userProfile?['email'] ?? userEmail ?? "Loading…";

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_AppColors.primary, _AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, spreadRadius: 1),
                  ],
                ),
                child: ClipOval(
                  child: profileImg != null
                      ? CachedNetworkImage(
                          imageUrl: '${ApiService.baseUrl}/$profileImg',
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: Icon(Icons.person, size: 44, color: Colors.grey[400]),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: _AppColors.primarySoft,
                            child: Icon(Icons.person, size: 44, color: _AppColors.primary),
                          ),
                        )
                      : Container(
                          color: _AppColors.primarySoft,
                          child: Center(
                            child: Text(
                              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: _AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: GestureDetector(
                  onTap: _navigateToEditProfile,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)],
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 16, color: _AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            displayName.isNotEmpty ? displayName : "User",
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            displayEmail,
            style: TextStyle(fontSize: 13.5, color: Colors.white.withOpacity(0.85)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToEditProfile() async {
    final prefs = await SharedPreferences.getInstance();
    String email = prefs.getString('email') ?? '';
    String name = prefs.getString('name') ?? '';
    String mobileNo = prefs.getString('mobileNo') ?? '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(
          userProfile: {
            'firstName': name.split(" ").first,
            'lastName': name.split(" ").length > 1 ? name.split(" ").last : '',
            'email': email,
            'mobile': mobileNo,
            'gender': 'Male',
            'dateOfBirth': '',
          },
          onProfileUpdated: _loadProfile,
        ),
      ),
    );
  }

  Widget _buildProfileButton() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _navigateToEditProfile,
          icon: const Icon(Icons.edit_rounded, color: _AppColors.primary, size: 18),
          label: const Text(
            "Edit Profile",
            style: TextStyle(color: _AppColors.primary, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: _AppColors.primary, width: 1.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Section card + rows
  // ---------------------------------------------------------------------
  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _AppColors.textPrimary),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingOption(IconData icon, String label, VoidCallback onTap, {String? subtitle}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _AppColors.primarySoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: _AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _AppColors.textPrimary)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: _AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: _AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() => Divider(height: 18, color: Colors.grey.shade100, thickness: 1);

  Widget _buildProfileInfoItem(IconData icon, String label, String? value) {
    final hasValue = value != null && value.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 13.5, color: _AppColors.textSecondary)),
          const Spacer(),
          Text(
            hasValue ? value! : 'Not provided',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: hasValue ? _AppColors.textPrimary : Colors.grey.shade400,
              fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _confirmLogout,
          icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 19),
          label: const Text(
            "Log out",
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _AppColors.danger,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Loading / error states
  // ---------------------------------------------------------------------
  Widget _buildLoadingSkeleton() {
    Widget shimmerBox({double height = 14, double width = 120}) => Container(
          height: height,
          width: width,
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
        );

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          decoration: const BoxDecoration(
            color: _AppColors.primary,
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
          ),
          child: Column(
            children: [
              CircleAvatar(radius: 52, backgroundColor: Colors.white.withOpacity(0.2)),
              const SizedBox(height: 16),
              Container(height: 16, width: 140, color: Colors.white.withOpacity(0.25)),
              const SizedBox(height: 8),
              Container(height: 12, width: 180, color: Colors.white.withOpacity(0.18)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        for (int i = 0; i < 2; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.all(16),
            height: 130,
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shimmerBox(width: 140),
                const SizedBox(height: 16),
                shimmerBox(width: 200, height: 10),
                const SizedBox(height: 10),
                shimmerBox(width: 160, height: 10),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: _AppColors.dangerSoft, shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, color: _AppColors.danger, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              "Couldn't load your profile",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? '',
              style: const TextStyle(color: _AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppColors.background,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: _AppColors.primary,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingSkeleton()
            : _errorMessage != null
                ? _buildErrorState()
                : RefreshIndicator(
                    onRefresh: _loadProfile,
                    color: _AppColors.primary,
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      slivers: [
                        SliverToBoxAdapter(child: _buildProfileHeader()),
                        SliverToBoxAdapter(child: _buildProfileButton()),
                        SliverToBoxAdapter(
                          child: _buildSectionCard(
                            "Personal Information",
                            [
                              _buildProfileInfoItem(Icons.badge_outlined, "First name", _userProfile?['firstName']),
                              _buildDivider(),
                              _buildProfileInfoItem(Icons.badge_outlined, "Last name", _userProfile?['lastName']),
                              _buildDivider(),
                              _buildProfileInfoItem(Icons.wc_rounded, "Gender", _userProfile?['gender']),
                              _buildDivider(),
                              _buildProfileInfoItem(Icons.phone_outlined, "Mobile", _userProfile?['mobile']),
                              _buildDivider(),
                              _buildProfileInfoItem(Icons.cake_outlined, "Date of birth", _userProfile?['dateOfBirth']),
                              _buildDivider(),
                              _buildProfileInfoItem(Icons.numbers_rounded, "Age", _userProfile?['age']?.toString()),
                            ],
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _buildSectionCard(
                            "Account Settings",
                            [
                              _buildSettingOption(
                                Icons.lock_outline_rounded,
                                "Change Password",
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ChangePasswordPage()),
                                ),
                              ),
                              _buildDivider(),
                              // _buildSettingOption(
                              //   Icons.phone_iphone_rounded,
                              //   "Update Phone Number",
                              //   () => Navigator.push(
                              //     context,
                              //     MaterialPageRoute(builder: (_) => UpdatePhonePage()),
                              //   ),
                              // ),
                            ],
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _buildSectionCard(
                            "Privacy & Security",
                            [
                              _buildSettingOption(
                                Icons.link_rounded,
                                "Link User Account",
                                () async {
                                  SharedPreferences prefs = await SharedPreferences.getInstance();
                                  String? email = prefs.getString("username");

                                  if (email != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => LinkUserPage(userEmail: email)),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('No email found for this account')),
                                    );
                                  }
                                },
                              ),
                              _buildDivider(),
                              _buildSettingOption(
                                Icons.privacy_tip_outlined,
                                "Privacy Policy",
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => PrivacyPolicyPage()),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SliverToBoxAdapter(child: _buildLogoutButton()),
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 24, top: 4),
                            child: Center(
                              child: Text(
                                'Safe Pulse',
                                style: TextStyle(fontSize: 12, color: _AppColors.textSecondary),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}



class UpdatePhonePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Update Phone Number")),
      body: Center(child: Text("Update Phone Number Page")),
    );
  }
}

// class PrivacyPolicyPage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Privacy Policy")),
//       body: Center(child: Text("Privacy Policy Page")),
//     );
//   }
// }