import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:codmgo2/utils/profile_logic.dart';
import 'package:codmgo2/screens/dashboard_page.dart';
import 'package:codmgo2/screens/leave_dashboard.dart';
import 'package:codmgo2/screens/attendence_history.dart';
import 'package:codmgo2/utils/logout_logic.dart';
import 'package:image_picker/image_picker.dart';

import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:codmgo2/screens/help_screen.dart';

class ProfilePage extends StatefulWidget {
  final String? employeeId;

  const ProfilePage({Key? key, this.employeeId}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late ProfileLogic profileLogic;
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    profileLogic = context.read<ProfileLogic>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
      _loadCachedProfileImage();
    });
  }

  Future<void> _loadProfileData() async {
    try {
      if (widget.employeeId?.isNotEmpty == true) {
        final isValid = await profileLogic.validateEmployeeExists(widget.employeeId!);
        if (!isValid && mounted) {
          _showSnackBar('Invalid employee ID: ${widget.employeeId}', Colors.red);
          return;
        }
      }
      await profileLogic.loadProfile();
    } catch (e) {
      debugPrint('Error in _loadProfileData: $e');
      if (mounted) {
        _showSnackBar('Error loading profile: ${e.toString()}', Colors.red);
      }
    }
  }

  Future<void> _loadCachedProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profile_image_path');
    if (imagePath != null && await File(imagePath).exists() && mounted) {
      setState(() => _profileImage = File(imagePath));
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null || dateValue.toString().isEmpty) return 'N/A';
    try {
      return DateFormat('MMM dd, yyyy').format(DateTime.parse(dateValue.toString()));
    } catch (e) {
      return dateValue.toString();
    }
  }

  String _formatValue(dynamic value) =>
      value?.toString().isNotEmpty == true ? value.toString() : 'N/A';

  String _formatAadhar(dynamic value) =>
      value?.toString().isNotEmpty == true
          ? value.toString().replaceAll(RegExp(r'[^0-9]'), '')
          : 'N/A';

  Color _getPerformanceFlagColor(String? flag) {
    if (flag?.isEmpty != false) return Colors.grey;
    switch (flag!.toLowerCase()) {
      case 'green': return Colors.green;
      case 'yellow': return Colors.yellow;
      case 'orange': return Colors.orange;
      case 'red': return Colors.red;
      default: return Colors.grey;
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final picker = ImagePicker();

      // Show options for camera or gallery
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select Profile Photo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImageSourceButton(
                      Icons.photo_camera,
                      'Camera',
                          () => Navigator.pop(context, ImageSource.camera),
                    ),
                    _buildImageSourceButton(
                      Icons.photo_library,
                      'Gallery',
                          () => Navigator.pop(context, ImageSource.gallery),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      );

      if (source == null) return;

      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (pickedFile != null && mounted) {
        final imageFile = File(pickedFile.path);
        setState(() => _profileImage = imageFile);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image_path', imageFile.path);
        _showSnackBar('Profile photo updated successfully', Colors.green);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        _showSnackBar('Error updating profile photo', Colors.red);
      }
    }
  }

  Widget _buildImageSourceButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFF667EEA).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF667EEA).withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: const Color(0xFF667EEA)),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF667EEA),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onBottomNavTap(BuildContext context, int index) {
    if (index == 3) return;

    final profileData = context.read<ProfileLogic>().profileData;
    final employeeId = widget.employeeId ?? profileLogic.employeeId ?? '';

    final routes = [
          () => DashboardPage(
        employeeId: employeeId,
        firstName: _formatValue(profileData?['First_Name__c']),
        lastName: _formatValue(profileData?['Last_Name__c']),
      ),
          () => LeaveDashboardPage(employeeId: employeeId),
          () => AttendanceHistoryPage(employeeId: employeeId),
    ];

    if (index < routes.length) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => routes[index]()),
      );
    }
  }

  Widget _buildProfileHeader(Map<String, dynamic> profileData, Color cardColor, Color textColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickProfileImage,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white70, width: 3),
                    color: Colors.white.withOpacity(0.1),
                  ),
                  child: ClipOval(
                    child: _profileImage != null
                        ? Image.file(
                      _profileImage!,
                      fit: BoxFit.cover,
                      width: 100,
                      height: 100,
                      errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.person, size: 50, color: Colors.white70),
                    )
                        : const Icon(Icons.person, size: 50, color: Colors.white70),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${_formatValue(profileData['First_Name__c'])} ${_formatValue(profileData['Last_Name__c'])}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'ID: ${_formatValue(profileData['Employee_Code__c'])}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceFlag(String? flag, Color textColor, Color cardColor, bool isDarkMode) {
    if (flag?.isEmpty != false) return const SizedBox.shrink();

    final flagColor = _getPerformanceFlagColor(flag);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: flagColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flag, color: flagColor, size: 24),
          const SizedBox(width: 8),
          Text(
            'Performance Flag: $flag',
            style: TextStyle(
              color: flagColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> items, Color cardColor, bool isDarkMode, Color textColor, Color? subtitleColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: _buildInfoRows(items, textColor, subtitleColor, isDarkMode),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildInfoRows(List<Map<String, dynamic>> items, Color textColor, Color? subtitleColor, bool isDarkMode) {
    List<Widget> widgets = [];
    for (int i = 0; i < items.length; i++) {
      widgets.add(_buildInfoRow(items[i], textColor, subtitleColor));
      if (i < items.length - 1) {
        widgets.addAll([
          const SizedBox(height: 16),
          Divider(color: isDarkMode ? Colors.grey[700] : Colors.grey[200], thickness: 1, height: 1),
          const SizedBox(height: 16),
        ]);
      }
    }
    return widgets;
  }

  Widget _buildInfoRow(Map<String, dynamic> item, Color textColor, Color? subtitleColor) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF667EEA).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(item['icon'], color: const Color(0xFF667EEA), size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['label'],
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
              ),
              const SizedBox(height: 4),
              Text(
                item['value'],
                style: TextStyle(fontSize: 14, color: subtitleColor),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileLogic>(
      builder: (context, profileLogic, child) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final backgroundColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
        final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
        final textColor = isDarkMode ? Colors.white : const Color(0xFF2D3748);
        final subtitleColor = isDarkMode ? Colors.white70 : Colors.grey[600];

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            elevation: 0,
            toolbarHeight: 63,
            backgroundColor: cardColor,
            title: Text('Profile', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.w600)),
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: textColor),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HelpScreen(
                        employeeId: profileLogic.employeeId ?? widget.employeeId ?? '',
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.help_outline, color: Colors.green, size: 24),
                  label: const Text('Help', style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          body: profileLogic.isLoading
              ? const Center(child: CircularProgressIndicator())
              : profileLogic.errorMessage != null
              ? _buildErrorState(profileLogic.errorMessage!, textColor, subtitleColor)
              : profileLogic.profileData == null
              ? _buildNoDataState(textColor, subtitleColor)
              : _buildProfileContent(profileLogic.profileData!, cardColor, isDarkMode, textColor, subtitleColor),
        );
      },
    );
  }

  Widget _buildErrorState(String errorMessage, Color textColor, Color? subtitleColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error Loading Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
            const SizedBox(height: 8),
            Text(errorMessage, style: TextStyle(fontSize: 14, color: subtitleColor), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(
              'Employee ID: ${widget.employeeId ?? profileLogic.employeeId ?? 'Not available'}',
              style: TextStyle(fontSize: 12, color: subtitleColor, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => profileLogic.loadProfile(), child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataState(Color textColor, Color? subtitleColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 64, color: subtitleColor),
          const SizedBox(height: 16),
          Text('No Profile Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 8),
          Text('Unable to load profile information', style: TextStyle(fontSize: 14, color: subtitleColor)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () => profileLogic.loadProfile(), child: const Text('Reload')),
        ],
      ),
    );
  }

  Widget _buildProfileContent(Map<String, dynamic> profileData, Color cardColor, bool isDarkMode, Color textColor, Color? subtitleColor) {
    return RefreshIndicator(
      onRefresh: () => profileLogic.loadProfile(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(profileData, cardColor, textColor),
            const SizedBox(height: 18),
            _buildPerformanceFlag(profileData['Performance_Flag__c'], textColor, cardColor, isDarkMode),
            _buildSection('Contact Information', [
              {'label': 'Phone', 'value': _formatValue(profileData['Phone__c']), 'icon': Icons.phone},
              {'label': 'Email', 'value': _formatValue(profileData['Email__c']), 'icon': Icons.email},
            ], cardColor, isDarkMode, textColor, subtitleColor),
            const SizedBox(height: 18),
            _buildSection('Banking Information', [
              {'label': 'Bank Name', 'value': _formatValue(profileData['Bank_Name__c']), 'icon': Icons.account_balance},
              {'label': 'IFSC Code', 'value': _formatValue(profileData['IFSC_Code__c']), 'icon': Icons.code},
              {'label': 'Account Number', 'value': _formatValue(profileData['Bank_Account_Number__c']), 'icon': Icons.credit_card},
            ], cardColor, isDarkMode, textColor, subtitleColor),
            const SizedBox(height: 18),
            _buildSection('Personal Information', [
              {'label': 'Aadhar Number', 'value': _formatAadhar(profileData['Aadhar_Number__c']), 'icon': Icons.badge},
              {'label': 'PAN Card', 'value': _formatValue(profileData['PAN_Card__c']), 'icon': Icons.credit_card_outlined},
              {'label': 'Date of Birth', 'value': _formatDate(profileData['Date_of_Birth__c']), 'icon': Icons.cake},
              {'label': 'Work Location', 'value': _formatValue(profileData['Work_Location__c']), 'icon': Icons.location_on},
            ], cardColor, isDarkMode, textColor, subtitleColor),
            const SizedBox(height: 18),
            _buildSection('Employment Information', [
              {'label': 'Joining Date', 'value': _formatDate(profileData['Joining_Date__c']), 'icon': Icons.date_range},
              {'label': 'Reporting Manager', 'value': _formatValue(profileData['Reporting_Manager_Formula__c']), 'icon': Icons.supervisor_account},
              {'label': 'Annual Review Date', 'value': _formatDate(profileData['Annual_Review_Date__c']), 'icon': Icons.event_note},
              {'label': 'Department', 'value': _formatValue(profileData['Department__c']), 'icon': Icons.business},
            ], cardColor, isDarkMode, textColor, subtitleColor),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => LogoutLogic.showLogoutDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                child: const Text('Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }


}