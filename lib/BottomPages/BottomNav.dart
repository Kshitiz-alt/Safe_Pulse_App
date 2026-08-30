import 'package:Safe_pulse/Api/app_state.dart';
import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:Safe_pulse/Pages/UserRelationsPage.dart';
import 'package:Safe_pulse/Pages/ProfileManagementPage.dart';
import 'package:Safe_pulse/other pages/ContactPage.dart';
import 'package:Safe_pulse/other pages/ZoneCreationPage.dart';
import 'package:typicons_flutter/typicons_flutter.dart';

class BottomNav extends StatefulWidget {
  @override
  _BottomNavState createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav>
    with WidgetsBindingObserver {

  int _selectedIndex = 0;

  final List _pages = [
    UserRelationsPage(),
    ContactPage(),
    ZoneCreationPage(),
    ProfileManagementPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    setAppState(true); // ✅ App opened
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    setAppState(false); // ✅ App closed

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setAppState(true);
    } else if (state == AppLifecycleState.paused ||
               state == AppLifecycleState.detached) {
      setAppState(false);
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              color: Colors.black.withOpacity(0.2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: GNav(
              selectedIndex: _selectedIndex,
              onTabChange: _onItemTapped,

              tabBorderRadius: 20,
              gap: 5,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              duration: const Duration(milliseconds: 200),

              activeColor: Colors.white,
              tabBackgroundColor: Color(0xFF5C6BC0),

              tabs: const [
                GButton(
                  icon: Icons.dashboard,
                  text: 'Dashboard',
                ),
                GButton(
                  icon: Icons.message,
                  text: 'Contact',
                ),
                GButton(
                  icon: Icons.map,
                  text: 'Geofence',
                ),
                GButton(
                  icon: Typicons.user,
                  text: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}