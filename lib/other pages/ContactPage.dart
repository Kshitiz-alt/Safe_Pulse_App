import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:Safe_pulse/Api/ApiService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// -----------------------------------------------------------------------
/// Design tokens — shared visual language with the rest of the app
/// (see UserRelationsPage). Kept local to this file so it can be dropped
/// in independently; move to a shared file if you'd like a single source
/// of truth across screens.
/// -----------------------------------------------------------------------
class _AppColors {
  static const primary = Color(0xFF5C6BC0);
  static const primaryDark = Color(0xFF3F4BA0);
  static const primarySoft = Color(0xFFE8EAF9);
  static const success = Color(0xFF2E9E5B);
  static const successSoft = Color(0xFFE3F6EA);
  static const danger = Color(0xFFE0433D);
  static const dangerSoft = Color(0xFFFCEAE9);
  static const surface = Colors.white;
  static const background = Color(0xFFF6F7FB);
  static const textPrimary = Color(0xFF1F2333);
  static const textSecondary = Color(0xFF7B8094);
}

class _Gap {
  static const xs = SizedBox(height: 4, width: 4);
  static const sm = SizedBox(height: 8, width: 8);
  static const md = SizedBox(height: 16, width: 16);
  static const lg = SizedBox(height: 24, width: 24);
}

class ContactPage extends StatefulWidget {
  const ContactPage({Key? key}) : super(key: key);

  @override
  _ContactPageState createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> contacts = [];
  List<Map<String, dynamic>> _filteredContacts = [];
  Map<String, String> emergencyNumbers = {
    'Ambulance': '102',
    'Police': '100',
    'Fire': '101',
    'Emergency': '112',
  };
  bool _isLoading = true;
  String? userId;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredContacts = query.isEmpty
          ? List.from(contacts)
          : contacts
              .where((c) =>
                  (c['name'] as String).toLowerCase().contains(query) ||
                  (c['relation'] as String).toLowerCase().contains(query))
              .toList();
    });
  }

  Future<void> _loadUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString("userId");
      print('Loaded userId: $savedUserId');
      
      if (savedUserId != null) {
        setState(() {
          userId = savedUserId;
        });
        await _loadData();
      } else {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('User ID not found', isError: true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Failed to load user ID', isError: true);
    }
  }

  String getFullImageUrl(String? path) {
  if (path == null || path.isEmpty) return '';

  if (path.startsWith("http")) return path;

  final base = ApiService.baseUrl.endsWith('/')
      ? ApiService.baseUrl.substring(0, ApiService.baseUrl.length - 1)
      : ApiService.baseUrl;

  final cleanPath = path.startsWith('/') ? path : '/$path';

  return "$base$cleanPath";
}

  bool isDefaultImage(String path) {
    return path.contains('default-user-img');
  }

  Future<void> _loadData() async {
    try {
      if (userId == null) return;

      setState(() {
        _isLoading = true;
      });

      // Load emergency contacts
      final emergencyContacts = await _apiService.getEmergencyContacts(userId!);
      
      setState(() {
        emergencyNumbers = {
          'Ambulance': emergencyContacts['ambulance'] ?? '102',
          'Police': emergencyContacts['police'] ?? '100',
          'Fire': emergencyContacts['fire'] ?? '101',
          'Emergency': emergencyContacts['emergency'] ?? '112',
        };
      });

      // Load personal contacts
      final personalContacts = await _apiService.getMyContacts(userId: userId!);
      debugPrint('Loaded personal contacts: $personalContacts');
      setState(() {
        contacts = personalContacts.map((contact) {
          debugPrint("Image URL: ${contact['imageUrl']}");
          return {
            'name': contact['name'] ?? 'Unknown',
            'phone': contact['number'] ?? '',
            'email': '',
            'image':getFullImageUrl(contact['imageUrl'] ?? ''),
                // 'https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=200&auto=format&fit=crop',
            'relation': contact['relation'] ?? 'Contact',
            'isActive': contact['isActive'] ?? true,
            'address': ''
          };
        }).toList();
        _filteredContacts = List.from(contacts);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Failed to load contacts', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? _AppColors.danger : _AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    });
  }

  // ---------------------------------------------------------------------
  // Edit emergency numbers dialog
  // ---------------------------------------------------------------------
  Future<void> _showEditEmergencyNumbersDialog() async {
    final ambulanceController =
        TextEditingController(text: emergencyNumbers['Ambulance']);
    final policeController =
        TextEditingController(text: emergencyNumbers['Police']);
    final fireController =
        TextEditingController(text: emergencyNumbers['Fire']);
    final emergencyController =
        TextEditingController(text: emergencyNumbers['Emergency']);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Edit Emergency Numbers',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNumberEditField('Ambulance', ambulanceController,
                    Icons.local_hospital, Colors.red),
                _buildNumberEditField('Police', policeController,
                    Icons.local_police, Colors.blueGrey),
                _buildNumberEditField(
                    'Fire', fireController, Icons.fire_truck, Colors.orange),
                _buildNumberEditField('Emergency', emergencyController,
                    Icons.call, Colors.purple),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _apiService.updateEmergencyContacts(
                    userId: userId!,
                    ambulance: ambulanceController.text,
                    police: policeController.text,
                    fire: fireController.text,
                    emergency: emergencyController.text,
                  );

                  setState(() {
                    emergencyNumbers['Ambulance'] = ambulanceController.text;
                    emergencyNumbers['Police'] = policeController.text;
                    emergencyNumbers['Fire'] = fireController.text;
                    emergencyNumbers['Emergency'] = emergencyController.text;
                  });

                  Navigator.pop(context);
                  _showSnackBar('Emergency contacts updated');
                } catch (e) {
                  Navigator.pop(context);
                  _showSnackBar('Failed to update emergency contacts',
                      isError: true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNumberEditField(String label, TextEditingController controller,
      IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: color),
          filled: true,
          fillColor: _AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        keyboardType: TextInputType.phone,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_moon_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Emergency Contacts',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
              IconButton(
                icon: Icon(
                  _isSearching ? Icons.close_rounded : Icons.search_rounded,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchController.clear();
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Quick access to the people and services that matter most',
            style: TextStyle(
                color: Colors.white.withOpacity(0.88),
                fontSize: 13.5,
                height: 1.3),
          ),
          if (_isSearching) ...[
            const SizedBox(height: 16),
            _buildSearchField(),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search contacts…',
          hintStyle: const TextStyle(color: _AppColors.textSecondary),
          prefixIcon:
              const Icon(Icons.search_rounded, color: _AppColors.textSecondary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      size: 18, color: _AppColors.textSecondary),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Quick action dial pad
  // ---------------------------------------------------------------------
  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quick Dial',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _AppColors.textPrimary),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _showEditEmergencyNumbersDialog,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded,
                          size: 15, color: _AppColors.primary),
                      SizedBox(width: 4),
                      Text('Edit',
                          style: TextStyle(
                              fontSize: 13,
                              color: _AppColors.primary,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickActionButton(
                icon: Icons.local_hospital_rounded,
                label: 'Ambulance',
                color: Colors.red,
                onPressed: () => _confirmAndCall(
                    'Ambulance', emergencyNumbers['Ambulance']!),
              ),
              _buildQuickActionButton(
                icon: Icons.local_police_rounded,
                label: 'Police',
                color: Colors.blueGrey,
                onPressed: () =>
                    _confirmAndCall('Police', emergencyNumbers['Police']!),
              ),
              _buildQuickActionButton(
                icon: Icons.fire_truck_rounded,
                label: 'Fire',
                color: Colors.orange,
                onPressed: () =>
                    _confirmAndCall('Fire', emergencyNumbers['Fire']!),
              ),
              _buildQuickActionButton(
                icon: Icons.call_rounded,
                label: 'Emergency',
                color: Colors.purple,
                onPressed: () => _confirmAndCall(
                    'Emergency', emergencyNumbers['Emergency']!),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A light confirmation avoids accidental dials to real emergency
  /// services — a single mis-tap here has real-world consequences.
  Future<void> _confirmAndCall(String label, String number) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Call $label?'),
        content: Text('This will dial $number.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppColors.success,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Call'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _callNumber(number);
    }
  }

  // ---------------------------------------------------------------------
  // Contact list
  // ---------------------------------------------------------------------
  Widget _buildContactCard(BuildContext context, Map<String, dynamic> contact) {
    final relationColor = _getRelationColor(contact['relation']);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showContactDetails(context, contact),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: relationColor, width: 2),
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: contact['image'] ?? '',
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: relationColor.withValues(alpha: 0.1),
                        child: Icon(Icons.person, color: relationColor),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: relationColor.withValues(alpha: 0.1),
                        child: Icon(Icons.person, color: relationColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: _AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: relationColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          contact['relation'] ?? '',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: relationColor),
                        ),
                      ),
                    ],
                  ),
                ),
                _circleIconButton(
                  icon: Icons.call_rounded,
                  color: _AppColors.success,
                  tooltip: 'Call ${contact['name']}',
                  onPressed: () => _callNumber(contact['phone'] ?? ''),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }

  Color _getRelationColor(String? relation) {
    switch ((relation ?? '').toLowerCase()) {
      case 'father':
        return Colors.blue;
      case 'mother':
        return Colors.pink;
      case 'school':
        return Colors.orange;
      case 'emergency':
        return Colors.red;
      default:
        return _AppColors.primary;
    }
  }

  Future<void> _callNumber(String phoneNumber) async {
    final number = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (number.isEmpty) {
      _showSnackBar('No phone number on file', isError: true);
      return;
    }

    try {
      bool? res = await FlutterPhoneDirectCaller.callNumber(number);
      if (res != true) {
        final url = 'tel:$number';
        if (await canLaunch(url)) {
          await launch(url);
        }
      }
    } catch (e) {
      debugPrint('Error calling $number: $e');
      final url = 'tel:$number';
      if (await canLaunch(url)) {
        await launch(url);
      }
    }
  }

  void _showContactDetails(BuildContext context, Map<String, dynamic> contact) {
    final relationColor = _getRelationColor(contact['relation']);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          decoration: const BoxDecoration(
            color: _AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(5)),
              ),
              const SizedBox(height: 20),
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: relationColor, width: 3),
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: contact['image'] ?? '',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: relationColor.withOpacity(0.1),
                      child: Icon(Icons.person, size: 44, color: relationColor),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: relationColor.withOpacity(0.1),
                      child: Icon(Icons.person, size: 44, color: relationColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                contact['name'] ?? '',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: relationColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  contact['relation'] ?? '',
                  style: TextStyle(
                      fontSize: 13,
                      color: relationColor,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 24),
              if ((contact['phone'] ?? '').isNotEmpty)
                _buildDetailRow(
                    Icons.phone_rounded, contact['phone'], _AppColors.success),
              if ((contact['email'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                    Icons.email_rounded, contact['email'], _AppColors.primary),
              ],
              if ((contact['address'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDetailRow(Icons.location_on_rounded, contact['address'],
                    _AppColors.danger),
              ],
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _callNumber(contact['phone'] ?? ''),
                      icon: const Icon(Icons.call_rounded, size: 19),
                      label: const Text('Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if ((contact['email'] ?? '').isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final url = 'mailto:${contact['email']}';
                          if (await canLaunch(url)) {
                            await launch(url);
                          }
                        },
                        icon: const Icon(Icons.email_rounded, size: 19),
                        label: const Text('Email'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, color: _AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Loading / empty states
  // ---------------------------------------------------------------------
  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        height: 74,
        decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(radius: 25, backgroundColor: Colors.grey.shade300),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 12, width: 110, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Container(
                        height: 10, width: 60, color: Colors.grey.shade200),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyContacts() {
    final bool searching = _searchController.text.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: _AppColors.primarySoft, shape: BoxShape.circle),
              child: Icon(
                searching ? Icons.search_off_rounded : Icons.contacts_rounded,
                color: _AppColors.primary,
                size: 38,
              ),
            ),
            _Gap.md,
            Text(
              searching ? 'No matches found' : 'No contacts yet',
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: _AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              searching
                  ? 'Try a different name or relation.'
                  : 'Add the people you\'d want to reach in an emergency.',
              style: const TextStyle(
                  fontSize: 14, color: _AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (!searching) ...[
              _Gap.lg,
              ElevatedButton.icon(
                onPressed: () {
                  // Hook up to add-contact flow.
                },
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Add contact'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
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
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            if (!_isLoading) _buildQuickActionsSection(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Contacts',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _AppColors.textPrimary),
                  ),
                  if (!_isLoading)
                    Text(
                      '${_filteredContacts.length} ${_filteredContacts.length == 1 ? 'contact' : 'contacts'}',
                      style: const TextStyle(
                          fontSize: 13, color: _AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? _buildLoadingSkeleton()
                  : _filteredContacts.isEmpty
                      ? _buildEmptyContacts()
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: _AppColors.primary,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics()),
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: _filteredContacts.length,
                            itemBuilder: (context, index) => _buildContactCard(
                                context, _filteredContacts[index]),
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Add new contact functionality
        },
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add'),
        backgroundColor: _AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
      ),
    );
  }
}
